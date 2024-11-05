////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Realm

/**
This class represents the collection of model object schemas persisted to Realm.

When using Realm, `Schema` objects allow performing migrations and
introspecting the database's schema.

Schemas map to collections of tables in the core database.
*/
public final class Schema: Printable {

    // MARK: Properties

    internal let rlmSchema: RLMSchema

    /// `ObjectSchema`s for all object types in this Realm. Meant
    /// to be used during migrations for dynamic introspection.
    public var objectSchema: [ObjectSchema] {
        return (rlmSchema.objectSchema as! [RLMObjectSchema]).map { ObjectSchema($0) }
    }

    /// Returns a human-readable description of the object schemas contained in this schema.
    public var description: String { return rlmSchema.description }

    // MARK: Initializers

    internal init(_ rlmSchema: RLMSchema) {
        self.rlmSchema = rlmSchema
    }

    // MARK: ObjectSchema Retrieval

    /// Returns the object schema with the given class name, if it exists.
    public subscript(className: String) -> ObjectSchema? {
        if let rlmObjectSchema = rlmSchema.schemaForClassName(className) {
            return ObjectSchema(rlmObjectSchema)
        }
        return nil
    }
}

// MARK: Equatable

extension Schema: Equatable {}

/// Returns whether the two schemas are equal.
public func ==(lhs: Schema, rhs: Schema) -> Bool {
    return lhs.rlmSchema.isEqualToSchema(rhs.rlmSchema)
}
