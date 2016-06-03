//
//  AlbumViewController.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 27/05/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import MapKit

// MARK: - UIViewController Implementation
class AlbumViewController: UIViewController
{
    // MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    // MARK: - Public Variables
    var annotation: MKAnnotation?
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        mapView.removeAnnotations(mapView.annotations)
        if let annotation = annotation {
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
    
}

// MARK: - UICollectionViewDataSource Implementation
extension AlbumViewController: UICollectionViewDataSource
{
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return 6
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("imageView", forIndexPath: indexPath)
        let imageView = cell.viewWithTag(1) as! UIImageView
        imageView.image = UIImage(named: "pin")
        return cell
    }
}