/*
 * LocValueTransformerPluralVariantPick.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log

import XibLoc



class LocValueTransformerPluralVariantPick : LocValueTransformer {
	
	override class var serializedType: String {return "plural_variant_pick"}
	
	enum UnicodePluralValue : String {
		case zero = "zero"
		case one = "one"
		case two = "two"
		case few = "few"
		case many = "many"
		case other = "other"
		init?(string: String) {
			switch string.lowercased() {
			case "zero",  "z", "0": self = .zero
			case "one",   "o", "1": self = .one
			case "two",   "t", "2": self = .two
			case "few",   "f":      self = .few
			case "many",  "m":      self = .many
			case "other", "x":      self = .other
			default: return nil
			}
		}
	}
	
	override var isValid: Bool {
		return true
	}
	
	let numberReplacement: String
	let numberOpenDelim: String
	let numberCloseDelim: String
	
	let pluralUnicodeValue: UnicodePluralValue
	let pluralOpenDelim: String
	let pluralMiddleDelim: String
	let pluralCloseDelim: String
	
	let escapeToken: String?
	
	init(serialization: [String: Any]) throws {
		guard let vs = serialization["plural_value"] as? String, let v = UnicodePluralValue(string: vs), let nr = serialization["number_replacement"] as? String else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid plural value or number replacement."])
		}
		
		numberReplacement = nr
		pluralUnicodeValue = v
		
		if let d = serialization["number_open_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty number open delimiter, which is invalid."])}
			numberOpenDelim = d
		} else {numberOpenDelim = "#"}
		
		if let d = serialization["number_close_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty number close delimiter, which is invalid."])}
			numberCloseDelim = d
		} else {numberCloseDelim = "#"}
		
		if let d = serialization["plural_open_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty plural open delimiter, which is invalid."])}
			pluralOpenDelim = d
		} else {pluralOpenDelim = "<"}
		
		if let d = serialization["plural_middle_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty plural middle delimiter, which is invalid."])}
			pluralMiddleDelim = d
		} else {pluralMiddleDelim = ":"}
		
		if let d = serialization["plural_close_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty plural close delimiter, which is invalid."])}
			pluralCloseDelim = d
		} else {pluralCloseDelim = ">"}
		
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = nil}
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		var ret = [
			"number_replacement": numberReplacement,
			"number_open_delimiter": numberOpenDelim,
			"number_close_delimiter": numberCloseDelim,
			"plural_value": pluralUnicodeValue.rawValue,
			"plural_open_delimiter": pluralOpenDelim,
			"plural_middle_delimiter": pluralMiddleDelim,
			"plural_close_delimiter": pluralCloseDelim
		]
		if let e = escapeToken {ret["escape_token"] = e}
		return ret
	}
	
	/* https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
	 * https://www.unicode.org/reports/tr35/tr35-numbers.html#Operands
	 *
	 * English:               one:i=1&v=0
	 * German:                one:i=1&v=0
	 * Spanish:               one:n=1
	 * Italian:               one:i=1&v=0
	 * Hungarian:             one:n=1
	 * Portuguese (Portugal): one:i=1&v=0
	 * Turkish:               one:n=1
	 * Thai:                  N/A
	 * Chinese:               N/A
	 * Japanese:              N/A
	 * Greek:                 one:n=1
	 * French:                one:i=0,1
	 * Portuguese (Brazil):   one:i=0..1
	 * Polish:                one:i=1&v=0;              few:v=0&i%10=2..4&i%100!=12..14; many:v=0&((i!=1&i%10=0..1)|(i%10=5..9)|(i%100=12..14))
	 * Russian:               one:v=0&i%10=1&i%100!=11; few:v=0&i%10=2..4&i%100!=12..14; many:v=0&((i%10=0)|(i%10=5..9)|(i%100=11..14)) */
	override func apply(toValue value: String, withLanguage language: String) throws -> String {
		/* We only treat the integer cases. */
		let language = language.lowercased()
		
		let n: Int?
		let pluralityDefinition: PluralityDefinition
		if Set(["thai", "chinese", "japanese"]).contains(where: { language.range(of: $0) != nil }) {
			pluralityDefinition = PluralityDefinition(string: "(*)")
			n = (pluralUnicodeValue == .other ? 1 : nil)
		} else if Set(["english", "german", "spanish", "italian", "hungarian", "turkish", "greek", "french", "portuguese"]).contains(where: { language.range(of: $0) != nil }) {
			/* Technically, for French and Brazilian Portuguese, the plurality
			 * definition is "(0:1)(*)", but as we use 1 and 2 for the values of n,
			 * we don't care about the difference in the 0 case for these two
			 * languages! */
			pluralityDefinition = PluralityDefinition(string: "(1)(*)")
			switch pluralUnicodeValue {
			case .one:   n = 1
			case .other: n = 2
			default:     n = nil
			}
		} else if language.range(of: "polish") != nil {
			/* Note: We do not require the full plurality definition here as we use
			 *       static values when resolving the string... Let's put it anyway
			 *       for reference. */
			pluralityDefinition = PluralityDefinition(string: "(1)(2→4:^*[^1][2→4]$)?(*)")
			switch pluralUnicodeValue {
			case .one:   n = 1
			case .few:   n = 2
			case .many:  n = 5
			case .other: n = 5 /* Because we don't treat the float cases, “other” is the same as “many” */
			default:     n = nil
			}
		} else if language.range(of: "russian") != nil {
			/* Note: We do not require the full plurality definition here as we use
			 *       static values when resolving the string... Let's put it anyway
			 *       for reference. */
			pluralityDefinition = PluralityDefinition(string: "(1:^*[^1]1$)(2→4:^*[^1][2→4]$)?(*)")
			switch pluralUnicodeValue {
			case .one:   n = 1
			case .few:   n = 2
			case .many:  n = 5
			case .other: n = 5 /* Because we don't treat the float cases, “other” is the same as “many” */
			default:     n = nil
			}
		} else {
			throw MappingResolvingError.unknownLanguage
		}
		guard let nn = n else {return "---"} /* Code for “this value should be ignored” */
		
		let xibLocInfo = Str2StrXibLocInfo(
			defaultPluralityDefinition: pluralityDefinition, escapeToken: escapeToken,
			simpleSourceTypeReplacements: [OneWordTokens(leftToken: numberOpenDelim, rightToken: numberCloseDelim): { _ in self.numberReplacement }],
			pluralGroups: [(MultipleWordsTokens(leftToken: pluralOpenDelim, interiorToken: pluralMiddleDelim, rightToken: pluralCloseDelim), .int(nn))],
			identityReplacement: { $0 }
		)
		return value.applying(xibLocInfo: xibLocInfo)
	}
	
}