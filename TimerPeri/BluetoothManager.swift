//
//  BluetoothManager.swift
//  TimerPeri
//
//  Created by Jay Tucker on 5/28/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject {
    
    private let serviceUUID                = CBUUID(string: "D5C677E9-7090-452B-8251-CB3EA027FE4F")
    private let requestCharacteristicUUID  = CBUUID(string: "2B771F92-CBC8-4C69-816B-B844E87E9CD4")
    private let responseCharacteristicUUID = CBUUID(string: "CD565DAE-C38B-42A7-957C-7D2AAE75DD1D")
    
    private var peripheralManager: CBPeripheralManager!
    private var responseCharacteristic: CBMutableCharacteristic!
    private var isPoweredOn = false

    private var pendingResponse = ""
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    private func addService() {
        log("addService")
        let service = CBMutableService(type: serviceUUID, primary: true)
        let requestCharacteristic = CBMutableCharacteristic(
            type: requestCharacteristicUUID,
            properties: CBCharacteristicProperties.Write,
            value: nil,
            permissions: CBAttributePermissions.Writeable)
        responseCharacteristic = CBMutableCharacteristic(
            type: responseCharacteristicUUID,
            properties: CBCharacteristicProperties.Read,
            value: nil,
            permissions: CBAttributePermissions.Readable)
        service.characteristics = [requestCharacteristic, responseCharacteristic]
        peripheralManager.addService(service)
    }
    
    private func startAdvertising() {
        log("startAdvertising")
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
    }
    
    private func nameFromUUID(uuid: CBUUID) -> String {
        switch uuid {
        case serviceUUID: return "service"
        case requestCharacteristicUUID: return "requestCharacteristic"
        case responseCharacteristicUUID: return "responseCharacteristic"
        default: return "unknown"
        }
    }
    
    private func queueResponse(request: CBATTRequest) {
        log("queueResponse")
        
//        sendResponse(request)
        sendResponseDelayed(request)
    }
    
    private func sendResponse(request: CBATTRequest) {
        log("sendResponse")
        request.value = pendingResponse.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
        pendingResponse = ""
    }
    
    private func sendResponseDelayed(request: CBATTRequest) {
        log("sendResponseDelayed")
        let delay = 1.0 // calculateDelay()
        let delayStr = String(format: "%.3f", delay)
        log("will send response in \(delayStr) secs")
        let sendTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
        dispatch_after(sendTime, dispatch_get_main_queue()) {
            self.sendResponse(request)
        }
    }
    
    private func calculateDelay() -> Double {
        log("calculateDelay")
        
        let now = NSDate()
        var ti = now.timeIntervalSinceReferenceDate
        
        // round up to next send interval
        let sendInterval = 5.0
        ti = ti - (ti % sendInterval) + sendInterval
        let sendTime = NSDate(timeIntervalSinceReferenceDate: ti)
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        log("now  \(dateFormatter.stringFromDate(now))")
        log("send \(dateFormatter.stringFromDate(sendTime))")
        
        let delay = sendTime.timeIntervalSinceDate(now)
        return delay
    }
    
}

extension BluetoothManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(peripheralManager: CBPeripheralManager!) {
        var caseString: String!
        switch peripheralManager.state {
        case .Unknown:
            caseString = "Unknown"
        case .Resetting:
            caseString = "Resetting"
        case .Unsupported:
            caseString = "Unsupported"
        case .Unauthorized:
            caseString = "Unauthorized"
        case .PoweredOff:
            caseString = "PoweredOff"
        case .PoweredOn:
            caseString = "PoweredOn"
        default:
            caseString = "WTF"
        }
        log("peripheralManagerDidUpdateState \(caseString)")
        isPoweredOn = (peripheralManager.state == .PoweredOn)
        if isPoweredOn {
            addService()
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didAddService service: CBService!, error: NSError!) {
        var message = "peripheralManager didAddService \(nameFromUUID(service.UUID)) "
        if error == nil {
            message += "ok"
            log(message)
            startAdvertising()
        } else {
            message += "error " + error.localizedDescription
            log(message)
        }
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager!, error: NSError!) {
        var message = "peripheralManagerDidStartAdvertising "
        if error == nil {
            message += "ok"
        } else {
            message += "error " + error.localizedDescription
        }
        log(message)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveWriteRequests requests: [AnyObject]!) {
        log("peripheralManager didReceiveWriteRequests \(requests.count)")
        if requests.count == 0 {
            return
        }
        let request = requests[0] as! CBATTRequest
        pendingResponse = NSString(data: request.value, encoding: NSUTF8StringEncoding)! as String
        peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveReadRequest request: CBATTRequest!) {
        let serviceUUID = request.characteristic.service.UUID
        let serviceName = nameFromUUID(serviceUUID)
        let characteristicUUID = request.characteristic.UUID
        let characteristicName = nameFromUUID(characteristicUUID)
        log("peripheralManager didReceiveReadRequest \(serviceName) \(characteristicName)")
        if !pendingResponse.isEmpty {
            dispatch_async(dispatch_get_main_queue()) {
                self.queueResponse(request)
            }
        } else {
            log("no pending responses")
            peripheralManager.respondToRequest(request, withResult: CBATTError.RequestNotSupported)
        }
    }

}
