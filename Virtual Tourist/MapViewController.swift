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

private let placeholderTitle = "Searching..."

// MARK: - UIViewController Implementation
class MapViewController: UIViewController
{
    // MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet var longPressGestureRecogniser: UILongPressGestureRecognizer!
    
    // MARK: - Private Variables
    private var selectedPin: Pin?
    private var isDraggingPin: Bool = false
    private var fetchedResultsController: NSFetchedResultsController!
    private let geocoder = CLGeocoder()
    
    // MARK: - Public Variables
    var dataController: DataController!
    
    // MARK: - Overrides
    override func viewDidLoad()
    {
        super.viewDidLoad()
        fetchedResultsController = dataController.allPinsWithSortDescriptor(NSSortDescriptor(key: "title",
            ascending: true))
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
        selectedPin = nil
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
                if let selectedPin = selectedPin {
                    let nextVC = segue.destinationViewController as! AlbumViewController
                    nextVC.pinId = selectedPin.objectID
                    nextVC.dataController = dataController
                    for annotation in mapView.selectedAnnotations {
                        mapView.deselectAnnotation(annotation, animated: false)
                    }
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
    func annotationFor(pin: Pin) -> MKPointAnnotation?
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
    
    func pinFor(annotation: MKAnnotation) -> Pin?
    {
        let coordinate = annotation.coordinate
        let searchResult = fetchedResultsController.fetchedObjects?.first( {
            let pin = $0 as! Pin
            return pin.latitude?.doubleValue == coordinate.latitude &&
                pin.longitude!.doubleValue == coordinate.longitude
        })
        return searchResult as? Pin
    }
    
    func loadPin(pin: Pin)
    {
        mapView.addAnnotation(MKPointAnnotation(pin: pin))
    }
    
    func removePin(pin: Pin)
    {
        if let annotation = annotationFor(pin) {
            mapView.removeAnnotation(annotation)
        }
    }
    
    func selectPin(pin: Pin)
    {
        if let annotation = annotationFor(pin) {
            mapView.selectAnnotation(annotation, animated: true)
        }
    }
    
    func loadPins(pins: [Pin])
    {
        for pin in pins { loadPin(pin) }
    }
    
    func searchForTitleFor(pin: Pin)
    {
        let coordinate = CLLocationCoordinate2D(latitude: pin.latitude!.doubleValue,
            longitude: pin.longitude!.doubleValue)
        geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude,
            longitude: coordinate.longitude)) { (placemarks, error) in
            guard error == nil else {
                NSLog("\(error!.localizedDescription)\n\(error!.description)")
                return
            }
            if let placemark = placemarks?.first {
                self.dataController.mainThreadContext.performBlock {
                    pin.title = placemark.name
                    self.dataController.save()
                }
            }
            else { NSLog("No placemarks identified for location at coordinates \(coordinate)") }
        }
    }
    
    func handleError(error: NSError)
    {
        onMainQueueDo {
            let alertVC = UIAlertController(title: "Operation Failed", message: error.localizedDescription,
                preferredStyle: .Alert)
            alertVC.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil))
            self.presentViewController(alertVC, animated: true, completion: nil)
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
            let pin = dataController.createPin(longitude: coordinate.longitude, latitude: coordinate.latitude,
                title: placeholderTitle, errorHandler: self.handleError)
            searchForTitleFor(pin)
        }
    }
}

// MARK: - MKMapViewDelegate Implementation
extension MapViewController: MKMapViewDelegate
{
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView,
        didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState)
    {
        switch newState {
        case .Starting:
            isDraggingPin = true
            if let annotation = view.annotation as? MKPointAnnotation,
                let pin = pinFor(annotation) {
                dataController.deleteFromMainContext(pin)
            }
            break
        case .Ending:
            if let annotation = view.annotation as? MKPointAnnotation {
                let pin = dataController.createPin(longitude: annotation.coordinate.longitude,
                    latitude: annotation.coordinate.latitude, errorHandler: self.handleError)
                searchForTitleFor(pin)
            }
            isDraggingPin = false
            break
        case .Canceling:
            isDraggingPin = false
        default:
            break
        }
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView,
                calloutAccessoryControlTapped control: UIControl)
    {
        if control == view.rightCalloutAccessoryView {
            if let annotation = view.annotation as? MKPointAnnotation {
                selectedPin = (fetchedResultsController.fetchedObjects as! [Pin]).first {
                    $0.latitude?.doubleValue == annotation.coordinate.latitude &&
                    $0.longitude?.doubleValue == annotation.coordinate.longitude &&
                    $0.title == annotation.title
                }
                performSegueWithIdentifier("albumViewSegue", sender: self)
            }
        }
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView)
    {
        self.dataController.mainThreadContext.performBlock {
            if let annotation = view.annotation, let pin = self.pinFor(annotation) {
                if pin.title == placeholderTitle {
                    self.searchForTitleFor(pin)
                }
            }
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
            pinView!.draggable = true
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
        }
        return pinView
    }
}

// MARK: - NSFetchedResultsControllerDelegate Implementation
extension MapViewController: NSFetchedResultsControllerDelegate
{
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    {
        if isDraggingPin { return }
        onMainQueueDo {
            if let pin = anObject as? Pin {
                switch type {
                case .Insert:
                    self.loadPin(pin)
                    break
                case .Delete:
                    self.removePin(pin)
                    break
                case .Update, .Move:
                    if let annotation = self.annotationFor(pin) {
                        annotation.title = pin.title
                        self.selectPin(pin)
                    }
                    break
                }
            }
        }
    }
}

// MARK: - MKPointAnnotation Convenience Init
private extension MKPointAnnotation
{
    convenience init(pin: Pin)
    {
        self.init()
        coordinate = CLLocationCoordinate2D(latitude: pin.latitude!.doubleValue, longitude: pin.longitude!.doubleValue)
        title = pin.title
    }
}
