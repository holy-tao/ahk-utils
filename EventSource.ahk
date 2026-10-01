#Requires AutoHotkey v2.0

/**
 * A base class for other classes that emit events. `EventSource` implements an `OnEvent` API
 * identical to that of the built-in GUI objects. The only meaningful deviation is the added
 * wildcard event "" which invokes callbacks with (eventName, args...) and is called for every
 * event, after callbacks registered for specific events.
 */
class EventSource {

    __New(eventNames*) {
        this._events := Map()
        this._events.CaseSense := "off"
        this._events[""] := []
        for name in eventNames
            this._events[name] := []
    }

    /**
     * Register a new event handler. Callbacks follow `Gui.OnEvent` rules -- a callback may return
     * a non-empty value to prevent any remaining callbacks from being called.
     * 
     * EventSource has a special "meta-event" used "" which listens for all events. Its signature
     * is always `(eventName, args...) => Any`. Wildcard events are invoked after named events, and
     * are skipped if a named event is skipped.
     * 
     * @param {String} eventName name of the event to register a handler for.
     * @param {Func} callback event callback
     * @param {Integer} addRemove whether to append, prepend, or remove the event
     */
    OnEvent(eventName, callback, addRemove := 1) {
        this._AssertHasEvent(eventName)
        if !HasMethod(callback)
            throw TypeError("Object of type " Type(callback) " is not callable", -1, callback)

        switch addRemove {
            case 1: this._events[eventName].Push(callback)
            case -1: this._events[eventName].InsertAt(1, callback)
            case 0:
            for handler in this._events[eventName] {
                    if handler == callback
                    this._events[eventName].RemoveAt(A_Index)
                    }
                    throw ValueError("Callback not registered for event type '" eventName "'", -1, callback)
            default:
                throw ValueError("Unknown addRemove value", -1, addRemove)
        }
    }

    /**
     * Raise an event.
     *
     * @param {String} eventName event to raise
     * @param {Array<Any>} args arguments to pass to callbacks
     */
    RaiseEvent(eventName, args*) {
        this._AssertHasEvent(eventName)
        for callback in this._events[eventName] {
            ret := callback(args)
            if IsSet(ret) && ret
                return
        }

        if eventName != "*"
            this.RaiseEvent("*", eventName, args*)
    }
    /**
     * Raise an event in a new thread.
     *
     * Better for UI responsiveness, but depending on thread interruptibility, the event may not
     * fire immediately (or at all)
     *
     * @param {String} eventName event to raise
     * @param {Array<Any>} args arguments to pass to callbacks
     */
    RaiseEventAsync(eventName, args*) =>
        SetTimer(ObjBindMethod(this, "RaiseEvent", eventName, args*), -1)

    _AssertHasEvent(eventName) {
        if !(eventName is String)
            throw TypeError("Expected a String but got a(n) " Type(eventName), -2, eventName)
        if !this._events.Has(eventName)
            throw ValueError("Object of type " Type(this) " has no such event", -2, eventName)
    }
}