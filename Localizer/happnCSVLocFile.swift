/*
 * happnCSVLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/26/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



/* Must be a one-char string */
let CSV_SEPARATOR = ","

let PRIVATE_KEY_HEADER_NAME = "__Key"
let PRIVATE_ENV_HEADER_NAME = "__Env"
let PRIVATE_FILENAME_HEADER_NAME = "__Filename"
let PRIVATE_COMMENT_HEADER_NAME = "__Comments"
let FILENAME_HEADER_NAME = "File"
let COMMENT_HEADER_NAME = "Comments"



extension String {
	var csvCellValue: String {
		if self.rangeOfCharacterFromSet(NSCharacterSet(charactersInString: "\(CSV_SEPARATOR)\"\n\r")) != nil {
			/* Double quotes needed */
			let doubledDoubleQuotes = self.stringByReplacingOccurrencesOfString("\"", withString: "\"\"")
			return "\"\(doubledDoubleQuotes)\""
		} else {
			/* Double quotes not needed */
			return self
		}
	}
}

class happnCSVLocFile: Streamable {
	let filepath: String
	private var languages: [String]
	private var entries: [LineKey: [String: String]]
	
	/* *************** LineKey struct. Key for each entries in the happn CSV loc file. *************** */
	struct LineKey: Equatable, Hashable, Comparable {
		let locKey: String
		let env: String
		let filename: String
		let comment: String
		
		/* Used when comparing for lt or gt, but not for equality */
		let index: Int
		
		/* Not used when comparing line keys */
		let userReadableGroupComment: String
		let userReadableComment: String
		
		var hashValue: Int {
			return locKey.hashValue &+ env.hashValue &+ filename.hashValue &+ (comment.isEmpty ? 0 : 1)
		}
	}
	
	/* *** Init from path *** */
	convenience init?(fromPath path: String, inout error: NSError?) {
		var encoding: UInt = 0
		var filecontent: String?
		if NSFileManager.defaultManager().fileExistsAtPath(path) {
			filecontent = NSString(contentsOfFile: path, usedEncoding: &encoding, error: &error)
			if filecontent == nil {
				self.init(filepath: path, languages: [], entries: [:])
				return nil
			}
		}
		self.init(filepath: path, filecontent: (filecontent != nil ? filecontent! : ""), error: &error)
	}
	
	/* *** Init with file content *** */
	convenience init?(filepath path: String, filecontent: String, inout error: NSError?) {
		/* TODO: Parse the CSVLoc file */
		self.init(filepath: path, languages: [], entries: [:])
	}
	
	/* *** Init *** */
	init(filepath path: String, languages l: [String], entries e: [LineKey: [String: String]]) {
		filepath = path
		languages = l
		entries = e
	}
	
	func mergeXcodeStringsFiles(stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let env = "Xcode"
		var keys = [LineKey]()
		for stringsFile in stringsFiles {
			let (filenameNoLproj, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(stringsFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			for component in stringsFile.components {
				switch component {
				case let whiteSpace as XcodeStringsFile.WhiteSpace:
					if whiteSpace.stringValue.rangeOfString("\n\n", options: NSStringCompareOptions.LiteralSearch) != nil && !currentUserReadableComment.isEmpty {
						if !currentUserReadableGroupComment.isEmpty {
							currentUserReadableGroupComment += "\n\n\n"
						}
						currentUserReadableGroupComment += currentUserReadableComment
						currentUserReadableComment = ""
					}
					currentComment += whiteSpace.stringValue
				case let comment as XcodeStringsFile.Comment:
					if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
					currentUserReadableComment += comment.content.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).stringByReplacingOccurrencesOfString("\n * ", withString: "\n", options: NSStringCompareOptions.LiteralSearch)
					currentComment += comment.stringValue
				case let locString as XcodeStringsFile.LocalizedString:
					let refKey = LineKey(
						locKey: locString.key, env: env, filename: filenameNoLproj, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = locString.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				default:
					println("Got unknown XcodeStringsFile component \(component)")
				}
			}
		}
	}
	
	func mergeAndroidXMLLocStringsFiles(locFiles: [AndroidXMLLocFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let env = "Android"
		var keys = [LineKey]()
		for locFile in locFiles {
			let (filenameNoLanguage, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(locFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			for component in locFile.components {
				switch component {
				case let whiteSpace as AndroidXMLLocFile.WhiteSpace:
					if whiteSpace.stringValue.rangeOfString("\n\n", options: NSStringCompareOptions.LiteralSearch) != nil && !currentUserReadableComment.isEmpty {
						if !currentUserReadableGroupComment.isEmpty {
							currentUserReadableGroupComment += "\n\n\n"
						}
						currentUserReadableGroupComment += currentUserReadableComment
						currentUserReadableComment = ""
					}
					currentComment += whiteSpace.stringValue
				case let comment as AndroidXMLLocFile.Comment:
					if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
					currentUserReadableComment += comment.content.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).stringByReplacingOccurrencesOfString("\n * ", withString: "\n", options: NSStringCompareOptions.LiteralSearch)
					currentComment += comment.stringValue
				case let groupOpening as AndroidXMLLocFile.GroupOpening:
					let refKey = LineKey(
						locKey: "o"+groupOpening.fullString, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = "--"
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let groupClosing as AndroidXMLLocFile.GroupClosing:
					let refKey = LineKey(
						locKey: "c"+groupClosing.groupName+(groupClosing.nameAttr != nil ? " "+groupClosing.nameAttr! : ""),
						env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = "--"
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let locString as AndroidXMLLocFile.StringValue:
					let refKey = LineKey(
						locKey: "k"+locString.key, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = locString.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let arrayItem as AndroidXMLLocFile.ArrayItem:
					let refKey = LineKey(
						locKey: "a"+arrayItem.parentName+"\""+String(arrayItem.idx), env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = arrayItem.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let pluralItem as AndroidXMLLocFile.PluralItem:
					let refKey = LineKey(
						locKey: "p"+pluralItem.parentName+"\""+pluralItem.quantity, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = pluralItem.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				default:
					println("Got unknown AndroidXMLLocFile component \(component)")
				}
			}
		}
	}
	
	func writeTo<Target : OutputStreamType>(inout target: Target) {
		target.write("\(PRIVATE_KEY_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(PRIVATE_ENV_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(PRIVATE_FILENAME_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(PRIVATE_COMMENT_HEADER_NAME.csvCellValue)")
		target.write("\(CSV_SEPARATOR)\(FILENAME_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(COMMENT_HEADER_NAME.csvCellValue)");
		for language in languages {
			target.write("\(CSV_SEPARATOR)\(language.csvCellValue)")
		}
		target.write("\n")
		var previousBasename: String?
		for entry_key in sorted(entries.keys) {
			let value = entries[entry_key]!
			
			var basename = entry_key.filename
			if let slashRange = basename.rangeOfString("/", options: NSStringCompareOptions.BackwardsSearch) {
				if slashRange.startIndex != basename.endIndex {
					basename = basename.substringFromIndex(slashRange.startIndex.successor())
				}
			}
			if basename.hasSuffix(".strings") {basename = basename.stringByDeletingPathExtension}
			
			if basename != previousBasename {
				previousBasename = basename
				target.write("\n")
				target.write("\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)")
				target.write(("\\o/ \\o/ \\o/ " + previousBasename! + " \\o/ \\o/ \\o/").csvCellValue)
				target.write("\n")
			}
			
			/* Writing group comment */
			if !entry_key.userReadableGroupComment.isEmpty {
				target.write("\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)")
				target.write(entry_key.userReadableGroupComment.csvCellValue)
				target.write("\n")
			}
			
			let comment = "__" + entry_key.comment + "__" /* Adding text in front and at the end so editors won't fuck up the csv */
			target.write("\(entry_key.locKey.csvCellValue)\(CSV_SEPARATOR)\(entry_key.env.csvCellValue)\(CSV_SEPARATOR)\(entry_key.filename.csvCellValue)\(CSV_SEPARATOR)\(comment.csvCellValue)")
			target.write("\(CSV_SEPARATOR)\(basename.csvCellValue)\(CSV_SEPARATOR)\(entry_key.userReadableComment.csvCellValue)")
			for language in languages {
				if let languageValue = value[language] {
					target.write("\(CSV_SEPARATOR)\(languageValue.csvCellValue)")
				} else {
					target.write("\(CSV_SEPARATOR)")
				}
			}
			target.write("\n")
		}
	}
	
	private func getLanguageAgnosticFilenameAndAddLanguageToList(filename: String, withMapping languageMapping: [String: String]) -> (String, String) {
		var found = false
		var languageName = "(Unknown)"
		var filenameNoLproj = filename
		
		for (fn, ln) in languageMapping {
			if let range = filenameNoLproj.rangeOfString("/" + fn + "/") {
				assert(!found)
				found = true
				
				languageName = ln
				filenameNoLproj.replaceRange(range, with: "//LANGUAGE//")
			}
		}
		
		if find(languages, languageName) == nil {
			languages.append(languageName)
			sort(&languages)
		}
		
		return (filenameNoLproj, languageName)
	}
	
	private func getKeyFrom(refKey: LineKey, inout withListOfKeys keys: [LineKey]) -> LineKey {
		if let idx = find(keys, refKey) {
			return keys[idx]
		}
		keys.append(refKey)
		return refKey
	}
}

func ==(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	return k1.locKey == k2.locKey && k1.env == k2.env && k1.filename == k2.filename
}

func <=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey <= k2.locKey
}

func >=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey >= k2.locKey
}

func <(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey < k2.locKey
}

func >(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey > k2.locKey
}
