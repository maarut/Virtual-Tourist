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
    var pinId: NSManagedObjectID?
    var dataController: DataController!
    
    // MARK: - Private Variables
    private var allPhotos: NSFetchedResultsController!
    private var pinFromContext: NSFetchedResultsController!
    private var changes = [NSFetchedResultsChangeType: [NSIndexPath]]()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        if let pinId = pinId {
            let pin = self.dataController.mainContext.objectWithID(pinId) as! Pin
            self.allPhotos = self.dataController.allPhotosFor(pin)
            self.allPhotos.delegate = self
            self.pinFromContext = self.dataController.fetchedResultsControllerFor(pin)
            self.pinFromContext.delegate = self
            do {
                try self.allPhotos.performFetch()
                try self.pinFromContext.performFetch()
            }
            catch let error as NSError { NSLog("Unable to performFetch:\n\(error)") }
        }
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        mapView.removeAnnotations(mapView.annotations)
        if let pinId = pinId {
            let pin = self.dataController.mainContext.objectWithID(pinId) as! Pin
            if pin.photoContainer == nil { dataController.searchForImagesAt(pin) }
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude!.doubleValue,
                    longitude: pin.longitude!.doubleValue)
                annotation.title = pin.title
                mapView.setRegion(MKCoordinateRegionMakeWithDistance(annotation.coordinate, 1000, 1000), animated: true)
                mapView.addAnnotation(annotation)
                mapView.selectAnnotation(annotation, animated: true)
        }
    }
}

// MARK: - IBActions
extension AlbumViewController
{
    @IBAction func newCollectionTapped(sender: AnyObject)
    {
        if let pinId = pinId {
            let pin = dataController.mainContext.objectWithID(pinId) as! Pin
            let photos = ((pin.photoContainer as? PhotoContainer)?.photos ?? []).map { $0 as! NSManagedObject }
            dataController.deleteObjectsFromMainContext(photos)
            dataController.searchForImagesAt(pin, isImageRefresh: true)
        }
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
        allPhotos.managedObjectContext.performBlock {
            if let photo = self.allPhotos.objectAtIndexPath(indexPath) as? Photo {
                if photo.isDownloadingImage || photo.imageData == nil {
                    onMainQueueDo {
                        let alertView = UIAlertController(title: "Cannot Remove Image",
                            message: "Cannot remove image yet. " +
                            "Please wait for the download to complete, then try again.",
                            preferredStyle: .Alert)
                        alertView.addAction(UIAlertAction(title: "Dismiss", style: .Default,
                            handler: { _ in self.dismissViewControllerAnimated(true, completion: nil) } ))
                        self.presentViewController(alertView, animated: true, completion: nil)
                    }
                }
                else {
                    self.dataController.deleteFromMainContext(photo)
                }
            }
        }
    }
}

// MARK: - UICollectionViewDataSource Implementation
extension AlbumViewController: UICollectionViewDataSource
{
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return allPhotos.fetchedObjects?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("imageView", forIndexPath: indexPath)
        let imageView = cell.viewWithTag(1) as! UIImageView
        let activityIndicator = cell.viewWithTag(2) as! UIActivityIndicatorView
        imageView.image = nil
        allPhotos.managedObjectContext.performBlock {
            if self.allPhotos.fetchedObjects?.count ?? 0 < indexPath.row { return }
            if let photo = self.allPhotos.objectAtIndexPath(indexPath) as? Photo {
                if let imageData = photo.imageData {
                    onMainQueueDo {
                        activityIndicator.stopAnimating()
                        imageView.image = UIImage(data: imageData)
                    }
                }
                else if !photo.isDownloadingImage {
                    self.dataController.downloadImageFor(photo)
                    onMainQueueDo { activityIndicator.startAnimating() }
                }
            }
        }
        return cell
    }
}

// MARK: - NSFetchedResultsControllerDelegate Implementation
extension AlbumViewController: NSFetchedResultsControllerDelegate
{
    func controllerWillChangeContent(controller: NSFetchedResultsController)
    {
        changes = [:]
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.collectionView.performBatchUpdates({ 
            for (type, indexPaths) in self.changes {
                switch type {
                case .Insert:
                    self.collectionView.insertItemsAtIndexPaths(indexPaths)
                    break
                case .Delete:
                    self.collectionView.deleteItemsAtIndexPaths(indexPaths)
                    break
                default:
                    break
                }
            }
        }, completion: nil)
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    {
        switch controller {
        case allPhotos:
            switch type {
            case .Insert:
                if changes[.Insert] == nil { changes[.Insert] = [] }
                changes[.Insert]!.append(newIndexPath!)
                break
            case .Move:
                onMainQueueDo { self.collectionView.moveItemAtIndexPath(indexPath!, toIndexPath: newIndexPath!) }
                break
            case .Update:
                onMainQueueDo { self.collectionView.reloadItemsAtIndexPaths([indexPath!]) }
                break
            case .Delete:
                if changes[.Delete] == nil { changes[.Delete] = [] }
                changes[.Delete]!.append(indexPath!)
                break
            }
            break
        case pinFromContext:
            if let annotation = mapView.selectedAnnotations.first as? MKPointAnnotation {
                annotation.title = (anObject as? Pin)?.title
            }
            break
        default:
            break
        }
    }
}