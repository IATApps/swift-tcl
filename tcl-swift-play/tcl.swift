//
//  tcl.swift
//  tcl-swift-play
//
//  Created by Karl Lehenbauer on 4/6/16.
//  Copyright © 2016 FlightAware. All rights reserved.
//
// Free under the Berkeley license.
//

import Foundation

enum TclReturn: Int32 {
    case OK = 0
    case ERROR = 1
    case RETURN = 2
    case BREAK = 3
    case CONTINUE = 4
}

typealias SwiftTclFuncType = (TclInterp, [TclObj]) throws -> TclReturn

enum TclError: ErrorType {
    case WrongNumArgs(nLeadingArguments: Int, message: String)
    case ErrorMessage(message: String) // set error message in interpreter result
    case Error // error already set in interpreter result
}

// TclCommandBlock - when creating a Tcl command -> Swift
class TclCommandBlock {
    let swiftTclFunc: SwiftTclFuncType
    let interp: TclInterp
    
    init(myInterp: TclInterp, function: SwiftTclFuncType) {
        swiftTclFunc = function
        interp = myInterp
    }
    
    func invoke(objv: [TclObj]) throws -> TclReturn {
        do {
            let ret = try swiftTclFunc(interp, objv)
            return ret
        }
    }
}

// swift_tcl_bridger - this is the trampoline that gets called by Tcl when invoking a created Swift command
//   this declaration is the Swift equivalent of Tcl_ObjCmdProc *proc
func swift_tcl_bridger (clientData: ClientData, interp: UnsafeMutablePointer<Tcl_Interp>, objc: Int32, objv: UnsafePointer<UnsafeMutablePointer<Tcl_Obj>>) -> Int32 {
    let tcb = UnsafeMutablePointer<TclCommandBlock>(clientData).memory
    
    // construct an array containing the arguments
    // (go from 1 not 0 because we don't include the obj containing the command name)
    var objvec = [TclObj]()
    for i in 1..<Int(objc) {
        objvec.append(TclObj(objv[i]))
    }
    
    // invoke the Swift implementation of the Tcl command and return the value it returns
    do {
        let ret = try tcb.invoke(objvec).rawValue
        return ret
    } catch TclError.Error {
        return TCL_ERROR
    } catch TclError.ErrorMessage(let message) {
        tcb.interp.result = message
        return TCL_ERROR
    } catch TclError.WrongNumArgs(let nLeadingArguments, let message) {
        Tcl_WrongNumArgs(interp, Int32(nLeadingArguments), objv, message.cStringUsingEncoding(NSUTF8StringEncoding) ?? [])
    } catch (let error) {
        tcb.interp.result = "unknown error type \(error)"
        return TCL_ERROR
    }
    return TCL_ERROR
}

// TclObj - Tcl object class

class TclObj {
    let obj: UnsafeMutablePointer<Tcl_Obj>
    
    // various initializers to create a Tcl object from nothing, an int,
    // double, string, Tcl_Obj *, etc
    
    // init - initialize from nothing, get an empty Tcl object
    init() {
        obj = Tcl_NewObj()
		IncrRefCount(obj)
    }
    
    init(_ val: Int) {
        obj = Tcl_NewLongObj(val)
		IncrRefCount(obj)
    }
    
    init(_ val: String) {
        let string = val.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
        obj = Tcl_NewStringObj (string, -1)
		IncrRefCount(obj)
    }
    
    init(_ val: Double) {
        obj = Tcl_NewDoubleObj (val)
		IncrRefCount(obj)
    }
    
    // init - Initialize from a Tcl_Obj *
    init(_ val: UnsafeMutablePointer<Tcl_Obj>) {
        obj = val
        IncrRefCount(val)
    }
    
    // init - init from a set of Strings to a list
    init(_ set: Set<String>) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)

        for element in set {
            let string = element.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewStringObj (string, -1))
        }
    }
    
    // init from a set of Ints to a list
    init(_ set: Set<Int>) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)
        
        for element in set {
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewLongObj (element))
        }
    }
    
    // init from a Set of doubles to a list
    init(_ set: Set<Double>) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)
        
        for element in set {
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewDoubleObj (element))
        }
    }
    
    // init from an Array of Strings to a Tcl list
    init(_ array: [String]) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)
        
        for element in array {
            let string = element.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewStringObj (string, -1))
        }
    }
    
    // Init from an Array of Int to a Tcl list
    init (_ array: [Int]) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)
        
        for element in array {
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewLongObj(element))
        }
    }
    
    // Init from an Array of Double to a Tcl list
    init (_ array: [Double]) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)

        array.forEach {
            Tcl_ListObjAppendElement(nil, obj, Tcl_NewDoubleObj($0))
        }
    }

    // init from a String/String dictionary to a list
    init (_ dictionary: [String: String]) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)

        dictionary.forEach {
            let keyString = $0.0.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewStringObj (keyString, -1))
            let valueString = $0.1.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewStringObj (valueString, -1))
        }
    }
    
    // init from a String/Int dictionary to a list
    init (_ dictionary: [String: Int]) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)
        
        dictionary.forEach {
            let keyString = $0.0.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewStringObj (keyString, -1))
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewLongObj ($0.1))
        }
    }
   
    // init from a String/Double dictionary to a list
    init (_ dictionary: [String: Double]) {
        obj = Tcl_NewObj()
		IncrRefCount(obj)
        
        dictionary.forEach {
            let keyString = $0.0.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewStringObj (keyString, -1))
            Tcl_ListObjAppendElement (nil, obj, Tcl_NewDoubleObj ($0.1))
        }
    }
    
    // deinit - decrement the object's reference count.  if it goes below one
    // the object will be freed.  if not then something else has it and it will
    // be freed after the last use
    deinit {
        DecrRefCount(obj)
    }
    
    // various set functions to set the Tcl object from a string, Int, Double, etc
    var stringValue: String {
        get {
            return String.fromCString(Tcl_GetString(obj)) ?? ""
        }
        set {
            Tcl_SetStringObj (obj, newValue.cStringUsingEncoding(NSUTF8StringEncoding) ?? [], -1)
        }
    }

    // getInt - return the Tcl object as an Int or nil
    // if in-object Tcl type conversion fails
    var intValue: Int? {
        get {
            var longVal: CLong = 0
            let result = Tcl_GetLongFromObj (nil, obj, &longVal)
            if (result == TCL_ERROR) {
                return nil
            }
            return longVal
        }
        set {
            guard let val = newValue else {return}
            Tcl_SetLongObj (obj, val)
        }
    }
    
    // getDouble - return the Tcl object as a Double or nil
    // if in-object Tcl type conversion fails
    var doubleValue: Double? {
        get {
            var doubleVal: CDouble = 0
            let result = Tcl_GetDoubleFromObj (nil, obj, &doubleVal)
            if (result == TCL_ERROR) {
                return nil
            }
            return doubleVal
        }
        set {
            guard let val = newValue else {return}
            Tcl_SetDoubleObj (obj, val)
        }
    }

    // getInt - version of getInt that throws an error if object isn't an int
    // if interp is specified then a Tcl-generated message will be used
    func getInt(interp: TclInterp?) throws ->  Int {
        var longVal: CLong = 0
        let result = Tcl_GetLongFromObj (nil, obj, &longVal)
        if (result == TCL_ERROR) {
            if (interp == nil) {
                throw TclError.ErrorMessage(message: "conversion error")
            } else {
                throw TclError.Error
            }
        }
        return longVal
    }
    
    // getDouble - version of getDouble that throws an error if object can't
    // be read as a double.  if interp is specified then a Tcl-generated
    // message will be used
    func getDouble(interp: TclInterp?) throws -> Double {
        var doubleVal: CDouble = 0
        let result = Tcl_GetDoubleFromObj (interp!.interp, obj, &doubleVal)
        if (result == TCL_ERROR) {
            if (interp == nil) {
                throw TclError.ErrorMessage(message: "conversion error")
            } else {
                throw TclError.Error
            }
        }
        return doubleVal
    }

    // getObj - return the Tcl object pointer (Tcl_Obj *)
    func getObj() -> UnsafeMutablePointer<Tcl_Obj> {
        return obj
    }
    
    // lappend - append a Tcl_Obj * to the Tcl object list
    func lappend (value: UnsafeMutablePointer<Tcl_Obj>) -> Bool {
        return Tcl_ListObjAppendElement (nil, obj, value) != TCL_ERROR
    }
    
    // lappend - append an Int to the Tcl object list
    func lappend (value: Int) -> Bool {
        return self.lappend (Tcl_NewLongObj (value))
    }
    
    // lappend - append a Double to the Tcl object list
    func lappend (value: Double) -> Bool {
        return self.lappend (Tcl_NewDoubleObj (value))
    }
    
    // lappend - append a String to the Tcl object list
    func lappend (value: String) -> Bool {
        let cString = value.cStringUsingEncoding(NSUTF8StringEncoding) ?? []
        return self.lappend(Tcl_NewStringObj (cString, -1))
    }
    
    // lappend - append a tclObj to the Tcl object list
    func lappend (value: TclObj) -> Bool {
        return self.lappend(value)
    }
    
    // lappend - append an array of Int to the Tcl object list
    // (flattens them out)
    func lappend (array: [Int]) -> Bool {
        for element in array {
            if (!self.lappend(element)) {
                return false
            }
        }
        return true
    }
    
    // lappend - append an array of Int to the Tcl object list
    // (flattens them out)
    func lappend (array: [Double]) -> Bool {
        for element in array {
            if (!self.lappend(element)) {
                return false
            }
        }
        return true
    }
    
    // lappend - append an array of Int to the Tcl object list
    // (flattens them out)
    func lappend (array: [String]) -> Bool {
        for element in array {
            if (!self.lappend(element)) {
                return false
            }
        }
        return true
    }
    
    // llength - return the number of elements in the list if the contents of our obj can be interpreted as a list
    func llength () -> Int? {
        var count: Int32 = 0
        if (Tcl_ListObjLength(nil, obj, &count) == TCL_ERROR) {
            return nil
        }
        return Int(count)
    }
    
    // toDictionary - copy the tcl object as a list into a String/TclObj dictionary
    func toDictionary () -> [String: TclObj]? {
        var dictionary: [String: TclObj] = [:]
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}

        for i in 0.stride(to: objc-1, by: 2) {
            let keyString = String.fromCString(Tcl_GetString (objv[i]))
            dictionary[keyString ?? ""] = TclObj(objv[i+1])
        }
        return dictionary
    }
    
    // toArray - create a String array from the tcl object as a list
    func toArray () -> [String]? {
        var array: [String] = []
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}
        
        for i in 0..<Int(objc) {
            let string = String.fromCString(Tcl_GetString (objv[i]))
            array.append(string ?? "")
        }
        
        return array
    }
    
    // toArray - create an Int array from the tcl object as a list
    func toArray () -> [Int]? {
        var array: [Int] = []
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}
        
        for i in 0..<Int(objc) {
            var longVal: CLong = 0
            let result = Tcl_GetLongFromObj (nil, objv[i], &longVal)
            if (result == TCL_ERROR) {
                return nil
            }
            array.append(longVal)

        }
        
        return array
    }
    
    // toArray - create a Double array from the tcl object as a list
    func toArray () -> [Double]? {
        var array: [Double] = []
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}
        
        for i in 0..<Int(objc) {
            var doubleVal: CDouble = 0
            let result = Tcl_GetDoubleFromObj (nil, objv[i], &doubleVal)
            if (result == TCL_ERROR) {
                return nil
            }
            array.append(doubleVal)
            
        }
        
        return array
    }
    
    // toArray - create a TclObj array from the tcl object as a list,
    // each element becomes its own TclObj
    
    func toArray () -> [TclObj]? {
        var array: [TclObj] = []
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}
        
        for i in 0..<Int(objc) {
            array.append(TclObj(objv[i]))
        }
        
        return array
    }

    // toDictionary - copy the tcl object as a list into a String/String dictionary
    func toDictionary () -> [String: String]? {
        var dictionary: [String: String] = [:]
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}

        for i in 0.stride(to: Int(objc-1), by: 2) {
            let keyString = String.fromCString(Tcl_GetString (objv[i]))
            let valueString = String.fromCString(Tcl_GetString(objv[i+1]))

            dictionary[keyString ?? ""] = valueString ?? ""
        }
        return dictionary
    }
    
    // toDictionary - copy the tcl object as a list into a String/String dictionary
    func toDictionary () -> [String: Int]? {
        var dictionary: [String: Int] = [:]
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}
        
        for i in 0.stride(to: Int(objc-1), by: 2) {
            let keyString = String.fromCString(Tcl_GetString (objv[i]))
            var val: Int32 = 0
            Tcl_GetIntFromObj (nil, objv[i+1], &val)
            
            dictionary[keyString ?? ""] = Int(val)
        }
        return dictionary
    }

    // toDictionary - copy the tcl object as a list into a String/String dictionary
    func toDictionary () -> [String: Double]? {
        var dictionary: [String: Double] = [:]
        
        var objc: Int32 = 0
        var objv: UnsafeMutablePointer<UnsafeMutablePointer<Tcl_Obj>> = nil
        
        if Tcl_ListObjGetElements(nil, obj, &objc, &objv) == TCL_ERROR {return nil}
        
        for i in 0.stride(to: Int(objc-1), by: 2) {
            let keyString = String.fromCString(Tcl_GetString (objv[i]))
            var val = 0.0
            Tcl_GetDoubleFromObj (nil, objv[i+1], &val)
            
            dictionary[keyString ?? ""] = val
        }
        return dictionary
    }

}

// TclInterp - Tcl Interpreter class

class TclInterp {
    let interp: UnsafeMutablePointer<Tcl_Interp>
    
    // init - create and initialize a full Tcl interpreter
    init() {
        interp = Tcl_CreateInterp()
        Tcl_Init(interp)
    }
    
    // deinit - upon deletion of this object, delete the corresponding
    // Tcl interpreter
    deinit {
        Tcl_DeleteInterp (interp)
    }

    enum InterpErrors: ErrorType {
        case NotString(String)
        case EvalError(Int)
    }
    
    // eval - evaluate a string with the Tcl interpreter
    //
    // the Tcl result code (1 == error is the big one) is returned
    // this should probably be mapped to an enum in Swift
    func eval(code: String) throws -> Int {
        guard let cCode = code.cStringUsingEncoding(NSUTF8StringEncoding) else {
            throw InterpErrors.NotString(code)
        }
        let ret = Tcl_Eval(interp, cCode)
        defer {
            print("eval return code is \(ret)")
        }
        if ret != 0 {
            throw InterpErrors.EvalError(Int(ret))
        }

        return Int(ret)
    }
    
    // resultString - grab the interpreter result as a string
    var result: String {
        get {
            return (String.fromCString(Tcl_GetString(Tcl_GetObjResult(interp)))) ?? ""
        }
        set {
            guard let cCode = newValue.cStringUsingEncoding(NSUTF8StringEncoding) else {return}
            let obj: UnsafeMutablePointer<Tcl_Obj> = Tcl_NewStringObj(cCode, -1)
            Tcl_SetObjResult(interp, obj)
        }
    }
    
    // resultObj - set the interpreter result to the TclObj or return a TclObj based on the interpreter result
    var resultObj: TclObj {
        get {
            return TclObj(Tcl_GetObjResult(interp))
        }
        set {
            Tcl_SetObjResult(interp,resultObj.getObj())
        }
    }
    
    // setResult - set the interpreter result from a Double
    func setResult(val: Double) {
        Tcl_SetDoubleObj (Tcl_GetObjResult(interp), val)
    }
    
    // setResult - set the interpreter result from an Int
    func setResult(val: Int) {
        Tcl_SetLongObj (Tcl_GetObjResult(interp), val)
    }
    
    // getVar - return var as an UnsafeMUtablePointer<Tcl_Obj> (i.e. a Tcl_Obj *), or nil
    // if elementName is specified, var is an array, otherwise var is a variable
    // NB still need to handle FLAGS
    
    func getVar(varName: String, elementName: String? = nil, flags: Int = 0) -> UnsafeMutablePointer<Tcl_Obj> {
        
        guard let cVarName = varName.cStringUsingEncoding(NSUTF8StringEncoding) else {return nil}
        
        let cElementName = elementName?.cStringUsingEncoding(NSUTF8StringEncoding)
        
        if (cElementName == nil) {
            return Tcl_GetVar2Ex(interp, cVarName, nil, Int32(flags))
        } else {
            return Tcl_GetVar2Ex(interp, cVarName, cElementName!, Int32(flags))
        }
    }
    
    // getVar - return a TclObj containing var in a TclObj object, or nil
    func getVar(varName: String, elementName: String? = nil, flags: Int = 0) -> TclObj? {
        let obj: UnsafeMutablePointer<Tcl_Obj> = self.getVar(varName, elementName: elementName, flags: flags)
        
        if (obj == nil) {
            return nil
        }
        
        return TclObj(obj)
    }
    
    // getVar - return a TclObj containing var as an Int, or nil
    func getVar(varName: String, elementName: String? = nil, flags: Int = 0) -> Int? {
        let obj: UnsafeMutablePointer<Tcl_Obj> = self.getVar(varName, elementName: elementName, flags: flags)
        
        if (obj == nil) {
            return nil
        }
        
        var longVal: CLong = 0
        let result = Tcl_GetLongFromObj (nil, obj, &longVal)
        if (result == TCL_ERROR) {
            return nil
        }
        
        return longVal
    }
    
    // getVar - return a TclObj containing var as a Double, or nil
    func getVar(arrayName: String, elementName: String? = nil) -> Double? {
        let obj: UnsafeMutablePointer<Tcl_Obj> = self.getVar(arrayName, elementName: elementName)
        
        if (obj == nil) {
            return nil
        }
        
        var doubleVal: CDouble = 0
        let result = Tcl_GetDoubleFromObj (nil, obj, &doubleVal)
        if (result == TCL_ERROR) {
            return nil
        }
        
        return doubleVal
    }
    
    // getVar - return a TclObj containing var as a String, or nil
    func getVar(arrayName: String, elementName: String? = nil) -> String? {
        let obj: UnsafeMutablePointer<Tcl_Obj> = self.getVar(arrayName, elementName: elementName)
        
        if (obj == nil) {
            return nil
        }
        
        return (String.fromCString(Tcl_GetString(obj))) ?? nil
    }
    
    
    // setVar - set a variable or array element in the Tcl interpreter
    // from an UnsafeMutablePointer<Tcl_Obj> (i.e. a Tcl_Obj *)
    // returns true or false based on whether it succeeded or not
    func setVar(varName: String, elementName: String? = nil, value: UnsafeMutablePointer<Tcl_Obj>, flags: Int = 0) -> Bool {
        guard let cVarName = varName.cStringUsingEncoding(NSUTF8StringEncoding) else {return false}
        let cElementName = elementName!.cStringUsingEncoding(NSUTF8StringEncoding)
        
        let ret = Tcl_SetVar2Ex(interp, cVarName, cElementName!, value, Int32(flags))
        
        return (ret != nil)
    }
    
    // setVar - set a variable or array element in the Tcl interpreter to the specified Int
    func setVar(varName: String, elementName: String? = nil, value: String, flags: Int = 0) -> Bool {
        guard let cString = value.cStringUsingEncoding(NSUTF8StringEncoding) else {return false}
        let obj = Tcl_NewStringObj(cString, -1)
        return self.setVar(varName, elementName: elementName, value: obj, flags: flags)
    }
    
    // setVar - set a variable or array element in the Tcl interpreter to the specified Int
    func setVar(varName: String, elementName: String? = nil, value: Int, flags: Int = 0) -> Bool {
        let obj = Tcl_NewIntObj(Int32(value))
        return self.setVar(varName, elementName: elementName, value: obj, flags: flags)
    }
    
    // setVar - set a variable or array element in the Tcl interpreter to the specified Double
    func setVar(varName: String, elementName: String? = nil, value: Double, flags: Int = 0) -> Bool {
        let obj = Tcl_NewDoubleObj(value)
        return self.setVar(varName, elementName: elementName, value: obj, flags: flags)
    }
    
    // setVar - set a variable or array element in the Tcl interpreter to the specified TclObj
    func setVar(varName: String, elementName: String? = nil, obj: TclObj, flags: Int = 0) -> Bool {
        return self.setVar(varName, elementName: elementName, value: obj.getObj(), flags: flags)
    }
    
    // dictionaryToArray - set a String/String dictionary into a Tcl array
    func dictionaryToArray (arrayName: String, dictionary: [String: String], flags: Int = 0) {
        dictionary.forEach {
            setVar(arrayName, elementName: $0.0, value: $0.1, flags: flags)
        }
    }

    // dictionaryToArray - set a String/Int dictionary into a Tcl array
    func dictionaryToArray (arrayName: String, dictionary: [String: Int], flags: Int = 0) {
        dictionary.forEach {
            setVar(arrayName, elementName: $0.0, value: $0.1, flags: flags)
        }
    }

    // dictionaryToArray - set a String/Double dictionary into a Tcl array
    func dictionaryToArray (arrayName: String, dictionary: [String: Double], flags: Int = 0) {
        dictionary.forEach {
            setVar(arrayName, elementName: $0.0, value: $0.1, flags: flags)
        }
    }

    // create_command - create a new Tcl command that will be handled by the specified Swift function
    func create_command(name: String, SwiftTclFunction:SwiftTclFuncType) {
        let cname = name.cStringUsingEncoding(NSUTF8StringEncoding)!
        
        let cmdBlock = TclCommandBlock(myInterp: self, function: SwiftTclFunction)
        let _ = Unmanaged.passRetained(cmdBlock) // keep Swift from deleting the object
        // let ptr = unmanaged.toOpaque()
        let ptr = UnsafeMutablePointer<TclCommandBlock>.alloc(1)
        ptr.memory = cmdBlock
        
        Tcl_CreateObjCommand(interp, cname, swift_tcl_bridger, ptr, nil)
    }
}


