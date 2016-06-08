//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 26/05/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import MapKit
import CoreData

// MARK: - UIViewController Implementation
class MapViewController: UIViewController
{
    // MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet var longPressGestureRecogniser: UILongPressGestureRecognizer!
    
    // MARK: - Private Variables
    private var annotationToPassOn: MKAnnotation?
    private var fetchedResultsController: NSFetchedResultsController!
    private let geocoder = CLGeocoder()
    
    // MARK: - Public Variables
    var coreDataStack: CoreDataStack!
    
    // MARK: - Overrides
    override func viewDidLoad()
    {
        super.viewDidLoad()
        fetchedResultsController = coreDataStack.allPinsWithSortDescriptor(NSSortDescriptor(key: "title", ascending: true))
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        }
        catch let error as NSError {
            NSLog("Unable to performFetch:\n\(error)")
        }
        if let pins = fetchedResultsController.fetchedObjects as? [Pin] {
            loadPins(pins)
        }
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
                    mapView.deselectAnnotation(annotationToPassOn, animated: false)
                }
                break
            default:
                break
            }
        }
    }
}

// MARK: - Pin -> MapView interface
private extension MapViewController
{
    func annotationForPin(pin: Pin) -> MKPointAnnotation?
    {
        let annotations = mapView.annotations as! [MKPointAnnotation]
        let index = annotations.indexOf {
            $0.coordinate.latitude == pin.latitude!.doubleValue &&
                $0.coordinate.longitude == pin.longitude!.doubleValue
        }
        if let index = index {
            return annotations[index]
        }
        return nil
    }
    
    func loadPin(pin: Pin)
    {
        mapView.addAnnotation(pin.toMKPointAnnotation())
    }
    
    func removePin(pin: Pin)
    {
        if let annotation = annotationForPin(pin) {
            mapView.removeAnnotation(annotation)
        }
    }
    
    func selectPin(pin: Pin)
    {
        if let annotation = annotationForPin(pin) {
            mapView.selectAnnotation(annotation, animated: true)
        }
    }
    
    func loadPins(pins: [Pin])
    {
        for pin in pins { loadPin(pin) }
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
            let pin = Pin(title: "", longitude: coordinate.longitude, latitude: coordinate.latitude, context: fetchedResultsController.managedObjectContext)
            geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), completionHandler: { (placemarks, error) in
                guard error == nil else {
                    NSLog("\(error!.localizedDescription)\n\(error!.description)")
                    return
                }
                if let placemark = placemarks?.first {
                    pin.title = placemark.name
                    self.coreDataStack.save()
                }
                else {
                    NSLog("No placemarks identified for location at coordinates \(coordinate)")
                }
            })
        }
    }
}

// MARK: - MKMapViewDelegate Implementation
extension MapViewController: MKMapViewDelegate
{
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl)
    {
        if control == view.rightCalloutAccessoryView {
            annotationToPassOn = view.annotation
            performSegueWithIdentifier("albumViewSegue", sender: self)
        }
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
            pinView!.canShowCallout = true
            pinView!.pinTintColor = UIColor.redColor()
            pinView!.animatesDrop = true
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
        }
        return pinView
    }
}

// MARK: - NSFetchedResultsControllerDelegate Implementation
extension MapViewController: NSFetchedResultsControllerDelegate
{
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    {
        if let pin = anObject as? Pin {
            switch type {
            case .Insert:
                loadPin(pin)
                break
            case .Delete:
                removePin(pin)
                break
            case .Update, .Move:
                if let annotation = annotationForPin(pin) {
                    annotation.title = pin.title
                    selectPin(pin)
                }
                break
            }
        }
    }
}

private extension Pin
{
    func toMKPointAnnotation() -> MKPointAnnotation
    {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: self.latitude!.doubleValue, longitude: self.longitude!.doubleValue)
        annotation.title = self.title
        return annotation
    }
}
