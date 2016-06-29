//
//  AlbumViewController.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 27/05/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import MapKit
import CoreData

// MARK: - UIViewController Implementation
class AlbumViewController: UIViewController
{
    // MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    // MARK: - Public Variables
    var pin: Pin?
    var dataController: DataController!
    
    // MARK: - Private Variables
    private var fetchedResults: NSFetchedResultsController!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        if let pin = pin {
            fetchedResults = dataController.allPhotosFor(pin)
            fetchedResults.delegate = self
            do {
                try fetchedResults.performFetch()
            }
            catch let error as NSError {
                NSLog("Unable to performFetch:\n\(error)")
            }
            pin.addObserver(self, forKeyPath: "title", options: .New, context: nil)
        }
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        mapView.removeAnnotations(mapView.annotations)
        if let pin = pin {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude!.doubleValue,
                longitude: pin.longitude!.doubleValue)
            annotation.title = pin.title
            mapView.setRegion(MKCoordinateRegionMakeWithDistance(annotation.coordinate, 1000, 1000), animated: true)
            mapView.addAnnotation(annotation)
            mapView.selectAnnotation(annotation, animated: true)
        }
    }
    
    override func viewWillDisappear(animated: Bool)
    {
        super.viewWillDisappear(animated)
        pin?.removeObserver(self, forKeyPath: "title")
    }
}

// MARK: - IBActions
extension AlbumViewController
{
    @IBAction func newCollectionTapped(sender: AnyObject)
    {
        print("Search for new images from Flickr")
    }
}

// MARK: - MKMapViewDelegate Implementation
extension AlbumViewController: MKMapViewDelegate
{
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView?
    {
        guard !annotation.isKindOfClass(MKUserLocation) else { return nil }
        let reuseId = "pinView"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView != nil {
            pinView!.annotation = annotation
        }
        else {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.pinTintColor = UIColor.redColor()
            pinView!.animatesDrop = false
            pinView!.canShowCallout = true
        }
        return pinView
    }
}

// MARK: - UICollectionViewDelegate Implementation
extension AlbumViewController: UICollectionViewDelegate
{
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        if let photo = fetchedResults.objectAtIndexPath(indexPath) as? Photo {
            dataController.delete(photo)
        }
    }
}

// MARK: - UICollectionViewDataSource Implementation
extension AlbumViewController: UICollectionViewDataSource
{
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return fetchedResults.fetchedObjects?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("imageView", forIndexPath: indexPath)
        let imageView = cell.viewWithTag(1) as! UIImageView
        let activityIndicator = cell.viewWithTag(2) as! UIActivityIndicatorView
        imageView.image = nil
        if let photo = fetchedResults.objectAtIndexPath(indexPath) as? Photo {
            if let imageData = photo.imageData {
                activityIndicator.stopAnimating()
                imageView.image = UIImage(data: imageData)
            }
            else if !photo.isDownloading {
                dataController.downloadImageFor(photo)
                activityIndicator.startAnimating()
            }
        }
        return cell
    }
}

// MARK: - KVO
extension AlbumViewController
{
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?,
        context: UnsafeMutablePointer<Void>)
    {
        if keyPath == "title" {
            if let annotation = mapView.selectedAnnotations.first as? MKPointAnnotation {
                annotation.title = (object as? Pin)?.title
            }
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate Implementation
extension AlbumViewController: NSFetchedResultsControllerDelegate
{
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    {
        onMainQueueDo {
            switch type {
            case .Insert, .Move, .Update:
                self.collectionView.reloadData()
                break
            case .Delete:
                if let indexPath = indexPath {
                    self.collectionView.deleteItemsAtIndexPaths([indexPath])
                }
                break
            }
        }
    }
}