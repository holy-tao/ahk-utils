#Requires AutoHotkey v2.0

/**
 * A record is a type backed by a {@link https://www.autohotkey.com/docs/v2/lib/Map.htm `Map`} whose properties are
 * typed and validated. Records provide utility methods for construction, copying, structural comparison, enumeration,
 * and more.
 *
 * Declare a record as a class with instance properties. The properties' values are *transforms* and are used to
 * validate and coerce assigned values. In the simplest case, these can be the built-in primitive classes:
 *
 *      class User extends Record {
 *          id := Integer
 *          name := String
 *      }
 *
 * Note that record property names cannot collide with Map property names.
 * 
 * Assigning a numeric string to User will coerce or throw via `Integer.Call`:
 *
 *      myUser.id := "2"            ; legal
 *      myUser.id := { value: 3 }   ; TypeError
 *
 * Transforms can also be functions that return the potentially transformed value to be used:
 *
 *      class Contrived extends Record {
 *          id := StrUpper
 *      }
 *
 * To define a default value, use an array with two elements `[transform, default]`. A field *without* a default is
 * **required**: constructing the record without supplying it throws.
 *
 *      class User extends Record {
 *          id := Integer               ; required
 *          name := [StrTitle, "N/A"]   ; optional, defaults to "N/A"
 *      }
 *
 * Construct with either a single object of field values, or `Map`-style key/value pairs:
 *
 *      User({ id: 1, name: "bob" })    ; => User { id: 1, name: "Bob" }
 *      User("id", 1, "name", "bob")    ; identical
 *
 * Because Record properties are declared as instance properties, most LSPs pick up their JSDoc comments
 * automatically. The per-field accessors are installed on the class prototype once, lazily, on first construction,
 * so the schema is also available statically via {@link Record.Default}.
 *
 * Records may be subclassed; a derived record inherits its base's fields and may add or override its own:
 *
 *      class Child extends Person {
 *          guardian := Person      ; a nested record field
 *      }
 *
 * A field whose transform is itself a record class (like `guardian` above) accepts an existing instance as well
 * as an initializer object, because constructing a record from a record of the same shape re-validates and copies
 * it. So `Person(existingPerson)` is a copy-construct, and no `v is Person ? v : Person(v)` wrapper is needed.
 */
class Record extends Map {
    /**
     * List of known concrete subclasses - className -> Map(fieldName -> {transform, default?})
     * @type {Map<String, Map<String, Object>>}
     */
    static _schemas := Map()
    /**
     * Constructing `Sub(Record._Probe)` builds the schema without validating/applying anything
     */
    static _Probe := Object()

    /**
     * Create a new record. Records can be initialized with a variadic array of fieldName, value pairs
     * (like `Map.__New`), with an object whose keys are the field names, or with another record whose fields are
     * copied and re-validated.
     *
     *      User({ id: 1, name: "bob" })    ; => User { id: 1, name: "Bob" }
     *      User("id", 1, "name", "bob")    ; identical
     *      User(existingUser)              ; copy-construct
     *
     * @param {Object | Record | Array} args initializer
     */
    __New(args*) {
        ; schema-only probe (used by static Default before any real instance exists)
        if args.Length = 1 && args[1] == Record._Probe {
            Record._EnsureSchema(this)
            return
        }

        schema := Record._EnsureSchema(this)

        ; __Init wrote the raw declarations as own props, shadowing the prototype accessors - remove them
        for name in schema 
            if this.HasOwnProp(name)
                this.DeleteProp(name)
        this.CaseSense := false

        ; apply declared defaults
        for name, spec in schema
            if spec.HasProp("default"){
                ;@ahkbuild-safe
                this.%name% := spec.default
            }

        provided := Record._Collect(args)
        for name, value in provided {
            this._EnsureField(schema, name)
            ;@ahkbuild-safe
            this.%name% := value
        }

        ; enforce required fields (no default, not provided)
        for name, spec in schema
            if !spec.HasProp("default") && !provided.Has(name)
                throw ValueError('Missing required field "' name '" for ' type(this), -1, name)
    }

    /**
     * Return a new record of the same type with the given fields replaced (and re-validated). The original is
     * unchanged. Accepts the same argument forms as construction.
     *
     *      updated := user.With("name", "alice")
     *      updated := user.With({ name: "alice" })
     * 
     * @returns {Record} a copy of the record with the specified fields replaced
     */
    With(args*) {
        schema := Record._EnsureSchema(this)
        clone := this.Clone()

        for name, value in Record._Collect(args) {
            this._EnsureField(schema, name)
            ;@ahkbuild-safe
            clone.%name% := value
        }
        return clone
    }

    /**
     * Compares the current record with `other` structurally, that is, returns 1 if the `this` and `other`
     * are records of the same type with the same fields containing the same values. Nested records compare
     * recursively, other objects compare by identity. Strings are compared case-sensitively.
     * @param {Any} other object to compare `this` with 
     * @returns {Integer} 1 if `this` equals `other`, 0 otherwise
     */
    Equals(other) {
        if !(other is Record) || type(this) != type(other) || this.Count != other.Count
            return false
        for key, val in this {
            if !Map.Prototype.Has.Call(other, key)
                return false
            if !Record._ValueEq(val, Map.Prototype.Get.Call(other, key))
                return false
        }
        return true
    }

    ToString() {
        str := type(this) " { "
        for key, val in this {
            str .= Format("{1}: {2}", key, Stringify(val))
            if A_Index < this.Count
                str .= ", "
        }
        return str . " }"

        Stringify(val) {
            switch true {
                case val is String: return '"' val '"'
                case (val is Primitive) || HasMethod(val, "ToString", 0): return String(val)
                default: return Format("{1}@0x{2:0X}", type(val), ObjPtr(val))
            }
        }
    }

    /**
     * Retrieve either the default value of a record's field, or a new record instance with all fields initialized
     * to their defaults. In the latter case, if any field is required, this method throws an error.  Use
     * {@link Record.HasDefault} to check whether a given field is required.
     * 
     * @param {String | unset} field the field to retrieve. Omit to retrieve a default instance. 
     * @returns {Any} 
     */
    static Default(field?) {
        schema := Record._SchemaOf(this)
        if !IsSet(field)
            return this()

        this.Prototype._EnsureField(schema, field)
        spec := schema[field]
        if !spec.HasProp("default")
            throw ValueError('Field "' field '" is required and has no default', -1, field)

        return spec.default
    }

    /**
     * Whether `field` has a declared default (i.e. is optional).
     * @param {String} field the name of the field to check
     * @returns {Integer} 1 if `field` has a default value, 0 if not 
     */
    static HasDefault(field) {
        schema := Record._SchemaOf(this)
        this.Prototype._EnsureField(schema, field)
        return schema[field].HasProp("default")
    }

    /**
     * Ensure that we have a schema for the given record instance, construct one if we don't, and return it
     * 
     * @param {Record} inst instance to ensure 
     * @returns {Map<String, Object>} 
     */
    static _EnsureSchema(inst) {
        clsName := inst.base.__Class
        if Record._schemas.Has(clsName)
            return Record._schemas[clsName]

        schema := Map(), schema.CaseSense := false
        ; Raw field declarations as they appear on the instance after __Init. Because __Init chains through base
        ; classes, `inst` already carries the full, override-resolved field set (derived declarations shadow base
        ; ones), so a subclass's schema is built in one pass without walking the prototype chain here.
        rawDecls := Map(), rawDecls.CaseSense := false
        proto := inst.base
        for name, decl in ObjOwnProps(inst) {
            if name = "__Class"
                continue
            rawDecls[name] := decl

            if decl is Array {
                if decl.Length != 2
                    throw ValueError("A [transform, default] field spec needs exactly 2 elements", -1, name)
                transform := decl[1], hasDefault := true, default := decl[2]
            } else {
                transform := decl, hasDefault := false, default := ""
            }
            if !HasMethod(transform, , 1)
                throw TypeError("Record property transforms must be callable with one argument", -1, name)

            spec := { transform: transform }
            if hasDefault
                spec.default := default
            schema[name] := spec
            proto.DefineProp(name, Record._MakeProp(name, transform, hasDefault, default))
        }

        ; The field accessors now live on the prototype. The generated __Init would re-run the raw declaration
        ; assignments on every future construction, feeding e.g. `Integer` (the class) into the field's validating
        ; setter. Replace it with one that reproduces those raw declarations as plain own-value props, exactly as
        ; the generated __Init did. Reproducing the *full* set (base fields included) means a derived class's
        ; __Init chain still sees every inherited field on the instance, no matter which class was built first.
        proto.DefineProp("__Init", { call: (self, args*) => Record._Init(rawDecls, self) })
        Record._schemas[clsName] := schema
        return schema
    }

    static _Init(rawDecls, self) {
        for name, decl in rawDecls
            self.DefineProp(name, { value: decl })
    }

    /**
     * Returns the schema for the given Record class
     * @returns {Map<String, Object>} 
     */
    static _SchemaOf(cls) {
        clsName := cls.Prototype.__Class
        if Record._schemas.Has(clsName)
            return Record._schemas[clsName]
        cls(Record._Probe)   ; side effect: builds and caches the schema
        return Record._schemas[clsName]
    }

    /**
     * Make a validating property descriptor that could be fed into DefineProp for the given field
     * @returns {Object} 
     */
    static _MakeProp(name, transform, hasDefault, default) {
        getter := hasDefault
            ? (self) => Map.Prototype.Get.Call(self, name, default)
            : (self) => Map.Prototype.Get.Call(self, name)
        setter := (self, value) => Map.Prototype.Set.Call(self, name, transform(value))
        return { get: getter, set: setter }
    }

    static _Collect(args) {
        provided := Map(), provided.CaseSense := false
        ; A single record initializes from its fields (a copy-construct, and what makes a bare-class nested field
        ; like `guardian := Person` idempotent: `Person(existingPerson)` re-validates rather than choking).
        if args.Length = 1 && args[1] is Record {
            for key, value in args[1]
                provided[key] := value
            return provided
        }

        if args.Length = 1 {
            if !IsObject(args[1]) {
                throw TypeError("Single argument record initializers require an Object, but got a(n) " type(args[1]),
                    -2, args[1])
            }

            for key, value in ObjOwnProps(args[1])
                provided[key] := value
            return provided
        }

        if Mod(args.Length, 2) != 0 {
            throw ValueError("Map-style Record initializers need an even number of key/value parameters",
                -2, args.Length)
        }

        loop args.Length {
            key := args[A_Index], value := args[++A_Index]
            if !(key is String)
                throw TypeError("Expected a String key but got a(n) " type(key), -2, key)
            provided[key] := value
        }
        return provided
    }

    static _ValueEq(a, b) {
        if IsObject(a) || IsObject(b) {
            if !(IsObject(a) && IsObject(b))
                return false

            if a is Record && b is Record
                return a.Equals(b)

            if a is Array && b is Array {
                if a.Length != b.Length
                    return false
                loop a.Length {
                    if !Record._ValueEq(a[A_Index], b[A_Index])
                        return false
                }
                return true
            }
            
            return ObjPtr(a) = ObjPtr(b)
        }
        return a == b
    }

    _EnsureField(schema, name) {
        if !schema.Has(name)
            throw ValueError('Unknown field "' name '" for ' type(this), -2, name)
    }

    ;@Ahk2Exe-IgnoreBegin Force people to go through properties, but can remove for compiled scripts since no edits
    Get(*) => Record.ThrowIllegal("Get")
    Set(*) => Record.ThrowIllegal("Set")
    __Item[*] {
        get => Record.ThrowIllegal("__Item.get")
        set => Record.ThrowIllegal("__Item.set")
    }
    Delete(*) => Record.ThrowIllegal("Delete")
    Clear(*) => Record.ThrowIllegal("Clear")

    static ThrowIllegal(op) {
        throw MethodError(Format("``{1}`` is illegal on Records - use properties instead", op), -2, this)
    }
    ;@Ahk2Exe-IgnoreEnd
}