/*
 * LocValueTransformerInvalid.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocValueTransformerInvalid : LocValueTransformer {
	
	override var isValid: Bool {
		return false
	}
	
	let invalidSerialization: [String: Any]
	
	init(serialization: [String: Any]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: Any] {
		return invalidSerialization
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		throw NSError()
	}
	
}
