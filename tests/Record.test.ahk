#Include ../Record.ahk
#Include YUnit\Assert.ahk

class User extends Record {
    id := Integer                       ; required (no default)
    name := [StrTitle, "N/A"]           ; optional
    role := [String, "guest"]           ; optional
}

class Config extends Record {
    host := [String, "localhost"]
    port := [Integer, 8080]
}

class Point extends Record {
    x := Integer
    y := Integer
}

AsPoint(v) => v is Point ? v : Point(v)

class Segment extends Record {
    a := AsPoint
    b := AsPoint
}

; Exercises methods and computed properties living alongside fields. These are prototype members, not instance
; vars, so they must NOT be treated as fields, and must survive the __Init neutralization.
class Person extends Record {
    age := Integer
    firstName := StrTitle
    lastName := [StrTitle, "Doe"]

    LegalName => this.lastName ", " this.firstName

    FullName {
        get => this.firstName " " this.lastName
        set {
            arr := StrSplit(value, A_Space, , 2)
            this.firstName := arr[1]
            this.lastName := arr.Has(2) ? arr[2] : ""
        }
    }

    GetName() => this.firstName " " this.lastName
}

; Subclass: inherits age/firstName/lastName, adds a nested-record field.
class Child extends Person {
    guardian := Person
}

; Subclass that overrides an inherited field: age becomes optional (was required).
class AgedChild extends Person {
    age := [Integer, 0]
    guardian := Person
}

; Dedicated pairs to pin down construction-order independence deterministically (no other test touches them).
class ParentFirstBase extends Record {
    a := [Integer, 0]
}
class ParentFirstSub extends ParentFirstBase {
    b := [Integer, 0]
}
class ChildFirstBase extends Record {
    a := [Integer, 0]
}
class ChildFirstSub extends ChildFirstBase {
    b := [Integer, 0]
}

class RecordTests {
    class Construction {
        ObjectForm_CoercesAndTransforms() {
            u := User({ id: "7", name: "bob smith" })
            Assert.Equals(u.id, 7)
            Assert.Equals(u.name, "Bob Smith")
        }

        PairForm_CoercesAndTransforms() {
            u := User("id", "7", "name", "bob smith")
            Assert.Equals(u.id, 7)
            Assert.Equals(u.name, "Bob Smith")
        }

        ObjectAndPairForms_ProduceEqualRecords() {
            a := User({ id: 7, name: "bob smith", role: "admin" })
            b := User("id", 7, "name", "bob smith", "role", "admin")
            Assert.Equals(a.Equals(b), true)
        }

        StoredValue_IsTheTransformedValue() {
            u := User({ id: 3, name: "jane" })
            ; the underlying map holds the coerced/transformed value, not the input
            Assert.Equals(Map.Prototype.Get.Call(u, "name"), "Jane")
        }

        Count_ReflectsAssignedFields() {
            u := User({ id: 1 })            ; id + the two defaults
            Assert.Equals(u.Count, 3)
        }
    }

    class Defaults {
        UnprovidedOptionalField_UsesDefault() {
            u := User({ id: 1 })
            Assert.Equals(u.role, "guest")
        }

        Default_IsRunThroughItsTransform() {
            ; Config.host default "localhost" passes through String; Point-less proof: use a coercing default
            c := Config()
            Assert.Equals(c.port, 8080)
            Assert.Equals(c.host, "localhost")
        }

        ProvidedValue_OverridesDefault() {
            u := User({ id: 1, role: "admin" })
            Assert.Equals(u.role, "admin")
        }
    }

    class Validation {
        MissingRequiredField_Throws() {
            Assert.Throws(() => User({ name: "x" }), ValueError)
        }

        UnknownField_Throws() {
            Assert.Throws(() => User({ id: 1, bogus: 2 }), ValueError)
        }

        InvalidValue_ThrowsFromTransform() {
            Assert.Throws(() => User({ id: { not: "a number" } }), TypeError)
        }

        OddNumberOfPairs_Throws() {
            Assert.Throws(() => User("id", 1, "name"), ValueError)
        }

        NonStringKey_Throws() {
            Assert.Throws(() => User(1, "one"), TypeError)
        }
    }

    class Assignment {
        SettingField_RunsTransform() {
            u := User({ id: 1, name: "jane" })
            u.name := "mary jane"
            Assert.Equals(u.name, "Mary Jane")
        }

        SettingField_CoercesType() {
            u := User({ id: 1 })
            u.id := "42"
            Assert.Equals(u.id, 42)
        }

        SettingInvalidValue_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u.id := { obj: 1 }, TypeError)
        }
    }

    class With {
        OverridesGivenField() {
            u := User({ id: 1, role: "guest" })
            u2 := u.With("role", "admin")
            Assert.Equals(u2.role, "admin")
        }

        KeepsOtherFields() {
            u := User({ id: 7, name: "bob smith" })
            u2 := u.With("role", "admin")
            Assert.Equals(u2.id, 7)
            Assert.Equals(u2.name, "Bob Smith")
        }

        DoesNotMutateOriginal() {
            u := User({ id: 1, role: "guest" })
            u.With("role", "admin")
            Assert.Equals(u.role, "guest")
        }

        AcceptsObjectForm() {
            u := User({ id: 1 })
            u2 := u.With({ role: "admin", name: "sam" })
            Assert.Equals(u2.role, "admin")
            Assert.Equals(u2.name, "Sam")
        }

        RevalidatesNewValue() {
            u := User({ id: 1 })
            Assert.Throws(() => u.With("id", { obj: 1 }), TypeError)
        }

        UnknownField_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u.With("nope", 1), ValueError)
        }
    }

    class Equals {
        SameTypeSameValues_AreEqual() {
            a := User({ id: 1, name: "a" })
            b := User({ id: 1, name: "a" })
            Assert.Equals(a.Equals(b), true)
        }

        DifferentValues_AreNotEqual() {
            a := User({ id: 1, name: "a" })
            b := User({ id: 2, name: "a" })
            Assert.Equals(a.Equals(b), false)
        }

        DifferentTypes_AreNotEqual() {
            u := User({ id: 1 })
            p := Point({ x: 1, y: 2 })
            Assert.Equals(u.Equals(p), false)
        }

        NonRecord_IsNotEqual() {
            u := User({ id: 1 })
            Assert.Equals(u.Equals({ id: 1 }), false)
        }

        NestedRecords_CompareRecursively() {
            s1 := Segment({ a: { x: 0, y: 0 }, b: { x: 3, y: 4 } })
            s2 := Segment({ a: Point({ x: 0, y: 0 }), b: Point({ x: 3, y: 4 }) })
            Assert.Equals(s1.Equals(s2), true)
        }

        NestedRecordsDiffer_AreNotEqual() {
            s1 := Segment({ a: { x: 0, y: 0 }, b: { x: 3, y: 4 } })
            s2 := Segment({ a: { x: 0, y: 0 }, b: { x: 9, y: 9 } })
            Assert.Equals(s1.Equals(s2), false)
        }

        StringCase_IsSignificant() {
            a := User({ id: 1, role: "admin" })
            b := User({ id: 1, role: "ADMIN" })
            Assert.Equals(a.Equals(b), false)
        }
    }

    class ToStringGroup {
        RendersTypeAndFields() {
            u := User({ id: 7, name: "bob smith", role: "guest" })
            Assert.Equals(u.ToString(), 'User { id: 7, name: "Bob Smith", role: "guest" }')
        }

        RecursesIntoNestedRecords() {
            s := Segment({ a: { x: 0, y: 0 }, b: { x: 3, y: 4 } })
            Assert.Equals(s.ToString(), "Segment { a: Point { x: 0, y: 0 }, b: Point { x: 3, y: 4 } }")
        }
    }

    class StaticDefault {
        DefaultOfOptionalField_ReturnsDeclaredDefault() {
            Assert.Equals(Config.Default("port"), 8080)
        }

        DefaultWithNoArg_ReturnsFullyDefaultedInstance() {
            c := Config.Default()
            Assert.Equals(c.host, "localhost")
            Assert.Equals(c.port, 8080)
        }

        DefaultOfRequiredField_Throws() {
            Assert.Throws(() => User.Default("id"), ValueError)
        }

        DefaultNoArg_WithRequiredFields_Throws() {
            Assert.Throws(() => User.Default(), ValueError)
        }

        DefaultOfUnknownField_Throws() {
            Assert.Throws(() => User.Default("nope"), ValueError)
        }

        HasDefault_TrueForOptional() {
            Assert.Equals(User.HasDefault("name"), true)
        }

        HasDefault_FalseForRequired() {
            Assert.Equals(User.HasDefault("id"), false)
        }

        HasDefault_UnknownField_Throws() {
            Assert.Throws(() => User.HasDefault("nope"), ValueError)
        }
    }

    class MembersAlongsideFields {
        Method_Works() {
            p := Person({ age: 42, firstName: "bob" })
            Assert.Equals(p.GetName(), "Bob Doe")
        }

        ComputedGetter_Works() {
            p := Person({ age: 42, firstName: "bob", lastName: "jones" })
            Assert.Equals(p.LegalName, "Jones, Bob")
        }

        ComputedSetter_Works() {
            p := Person({ age: 42, firstName: "bob" })
            p.FullName := "Dave Smith"
            Assert.Equals(p.firstName, "Dave")
            Assert.Equals(p.lastName, "Smith")
        }

        ComputedProperties_AreNotFields() {
            p := Person({ age: 42, firstName: "bob" })
            ; only the three declared fields land in the map
            Assert.Equals(p.Count, 3)
        }

        SecondInstance_Works() {
            ; regression: the __Init neutralization must not break the 2nd+ construction
            a := Person({ age: 1, firstName: "a" })
            b := Person({ age: 2, firstName: "b" })
            Assert.Equals(a.GetName(), "A Doe")
            Assert.Equals(b.GetName(), "B Doe")
        }
    }

    class Subclassing {
        InheritedField_IsAccepted() {
            c := Child({ age: 7, firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            Assert.Equals(c.age, 7)
            Assert.Equals(c.firstName, "Alice")
        }

        OwnField_IsAccepted() {
            c := Child({ age: 7, firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            Assert.Equals(c.guardian.firstName, "Bob")
        }

        InheritedDefault_Applies() {
            c := Child({ age: 7, firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            Assert.Equals(c.lastName, "Doe")     ; inherited default
        }

        InheritedRequiredField_IsEnforced() {
            Assert.Throws(() => Child({ firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) }), ValueError)
        }

        OwnRequiredField_IsEnforced() {
            Assert.Throws(() => Child({ age: 7, firstName: "alice" }), ValueError)
        }

        Count_IncludesInheritedAndOwnFields() {
            c := Child({ age: 7, firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            Assert.Equals(c.Count, 4)            ; age, firstName, lastName, guardian
        }

        InheritedMethod_Works() {
            c := Child({ age: 7, firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            Assert.Equals(c.GetName(), "Alice Doe")
        }

        InheritedComputedSetter_Works() {
            c := Child({ age: 7, firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            c.FullName := "Ann Smith"
            Assert.Equals(c.firstName, "Ann")
            Assert.Equals(c.lastName, "Smith")
        }

        SameSubtype_EqualsStructurally() {
            g := Person({ age: 40, firstName: "bob" })
            a := Child({ age: 7, firstName: "alice", guardian: g })
            b := Child({ age: 7, firstName: "alice", guardian: g })
            Assert.Equals(a.Equals(b), true)
        }

        SubclassNotEqualToParent() {
            p := Person({ age: 7, firstName: "alice" })
            c := Child({ age: 7, firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            Assert.Equals(c.Equals(p), false)
        }

        ToString_IncludesInheritedAndOwnFields() {
            c := Child({ age: 7, firstName: "alice", lastName: "wu", guardian: Person({ age: 40, firstName: "bob" }) })
            ; fields serialize in alphabetical order (ObjOwnProps enumeration order)
            Assert.Equals(c.ToString(),
                'Child { age: 7, firstName: "Alice", guardian: Person { age: 40, firstName: "Bob", lastName: "Doe" }, lastName: "Wu" }')
        }

        OverriddenField_UsesDerivedSpec() {
            ; Person.age is required; AgedChild overrides it to optional with default 0
            c := AgedChild({ firstName: "alice", guardian: Person({ age: 40, firstName: "bob" }) })
            Assert.Equals(c.age, 0)
            Assert.Equals(AgedChild.HasDefault("age"), true)
        }

        HasDefault_ReadsInheritedField() {
            Assert.Equals(Child.HasDefault("lastName"), true)    ; inherited optional
            Assert.Equals(Child.HasDefault("age"), false)        ; inherited required
        }

        StaticDefault_ReadsInheritedField() {
            Assert.Equals(Child.Default("lastName"), "Doe")
        }

        BaseConstructedFirst_SubclassStillGetsInheritedFields() {
            ParentFirstBase()                                    ; build & neutralize base first
            s := ParentFirstSub({ a: 1, b: 2 })
            Assert.Equals(s.a, 1)
            Assert.Equals(s.b, 2)
            Assert.Equals(s.Count, 2)
        }

        SubclassConstructedFirst_BaseStillWorks() {
            s := ChildFirstSub({ a: 1, b: 2 })                   ; build subclass first
            Assert.Equals(s.a, 1)
            Assert.Equals(s.b, 2)
            base := ChildFirstBase({ a: 5 })
            Assert.Equals(base.a, 5)
            Assert.Equals(base.Count, 1)
        }
    }

    class IllegalMapOps {
        ItemGet_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u["id"], MethodError)
        }

        ItemSet_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u["id"] := 2, MethodError)
        }

        Get_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u.Get("id"), MethodError)
        }

        Set_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u.Set("id", 2), MethodError)
        }

        Delete_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u.Delete("id"), MethodError)
        }

        Clear_Throws() {
            u := User({ id: 1 })
            Assert.Throws(() => u.Clear(), MethodError)
        }
    }
}
