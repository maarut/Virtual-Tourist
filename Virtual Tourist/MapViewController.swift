//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 26/05/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import MapKit

// MARK: - UIViewController Implementation
class MapViewController: UIViewController
{
    // MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet var longPressGestureRecogniser: UILongPressGestureRecognizer!
    
    // MARK: - Private Variables
    private var annotationToPassOn: MKAnnotation?
    
    // MARK: - Overrides
    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidDisappear(animated: Bool)
    {
        super.viewDidDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if let id = segue.identifier {
            switch id {
            case "albumViewSegue":
                if let annotationToPassOn = annotationToPassOn {
                    let nextVC = segue.destinationViewController as! AlbumViewController
                    nextVC.annotation = annotationToPassOn
                }
                break
            default:
                break
            }
        }
    }
}

// MARK: - IBActions
extension MapViewController
{
    @IBAction func longPressGestureRecognised(sender: UILongPressGestureRecognizer)
    {
        if sender.state == .Began {
            let location = sender.locationInView(mapView)
            let coordinate = mapView.convertPoint(location, toCoordinateFromView: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Title"
            annotation.subtitle = "Description"
            mapView.addAnnotation(annotation)
        }
    }
}

// MARK: - MKMapViewDelegate Implementation
extension MapViewController: MKMapViewDelegate
{
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView)
    {
        annotationToPassOn = view.annotation
        performSegueWithIdentifier("albumViewSegue", sender: self)
    }
    
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
            pinView!.animatesDrop = true
        }
        return pinView
    }
}
