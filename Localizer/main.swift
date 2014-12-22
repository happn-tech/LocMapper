/*
 * main.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

func usage<TargetStream: OutputStreamType>(program_name: String, inout stream: TargetStream) {
	println("Usage: \(program_name) command [args ...]", &stream)
	println("", &stream)
	println("Commands are:", &stream)
	println("   export_from_xcode [--exclude=excluded_path ...] root_folder output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", &stream)
	println("      Exports and merges all the .strings files in the project to output_file.csv, excluding all paths containing any excluded_path", &stream)
	println("", &stream)
	println("   import_to_xcode input_file.csv root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]", &stream)
	println("      Imports and merges input_file.csv to the existing .strings in the project", &stream)
	println("", &stream)
	println("   export_from_android [--res-folder=res_folder] [--strings-filename=name ...] root_folder output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", &stream)
	println("      Exports and merges the localization files of the android project to output_file.csv", &stream)
	println("", &stream)
	println("   import_to_android [--res-folder=res_folder] [--strings-filename=name ...] input_file.csv root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]", &stream)
	println("      Imports and merges input_file.csv to the existing strings files of the android project", &stream)
}

/* Returns the arg at the given index, or prints "Syntax error: error_message"
 * and the usage, then exits with syntax error if there is not enough arguments
 * given to the program */
func argAtIndexOrExit(i: Int, error_message: String) -> String {
	if Process.arguments.count <= i {
		println("Syntax error: \(error_message)", &mx_stderr)
		usage(Process.arguments[0], &mx_stderr)
		exit(1)
	}
	
	return Process.arguments[i]
}

func getFolderToHumanLanguageNamesFromIndex(var i: Int) -> [String: String] {
	var folder_name_to_language_name = [String: String]()
	
	while i < Process.arguments.count {
		let folder_name = argAtIndexOrExit(i++, "INTERNAL ERROR")
		let language_name = argAtIndexOrExit(i++, "Language name is required for a given folder name")
		if folder_name_to_language_name[folder_name] != nil {
			println("Syntax error: Folder name \(folder_name) defined more than once", &mx_stderr)
			usage(Process.arguments[0], &mx_stderr)
			exit(1)
		}
		folder_name_to_language_name[folder_name] = language_name
	}
	
	if folder_name_to_language_name.count == 0 {
		println("Syntax error: Expected at least one language. Got none.", &mx_stderr)
		usage(Process.arguments[0], &mx_stderr)
		exit(1)
	}
	
	return folder_name_to_language_name
}

/* Takes the current arg position in input and a dictionary of long args names
 * with the corresponding action to execute when the long arg is found.
 * Returns the new arg position when all long args have been found. */
func getLongArgs(argIdx: Int, longArgs: [String: (String) -> Void]) -> Int {
	var i = argIdx
	
	func stringByDeletingPrefixIfPresent(prefix: String, from string: String) -> String? {
		if string.hasPrefix(prefix) {
			var start_idx = string.startIndex
			for _ in 0..<countElements(prefix) {start_idx = start_idx.successor()} /* There doesn't seem to be any easier way to do this... */
			return string[start_idx..<string.endIndex]
		}
		
		return nil
	}
	
	
	longArgLoop: while true {
		let arg = argAtIndexOrExit(i++, "Syntax error")
		
		for (longArg, action) in longArgs {
			if let no_prefix = stringByDeletingPrefixIfPresent("--\(longArg)=", from: arg) {
				action(no_prefix)
				continue longArgLoop
			}
		}
		
		if arg != "--" {--i}
		break
	}
	
	return i
}

func writeText(text: String, toFile filePath: String, usingEncoding encoding: NSStringEncoding, inout err: NSError?) -> Bool {
	if let data = text.dataUsingEncoding(encoding, allowLossyConversion: false) {
		if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
			if !NSFileManager.defaultManager().removeItemAtPath(filePath, error: &err) {
				return false
			}
		}
		if !NSFileManager.defaultManager().createFileAtPath(filePath, contents: nil, attributes: nil) {
			err = NSError(domain: "LocalizerErrDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot file at path \(filePath)"])
			return false
		}
		if let output_stream = NSFileHandle(forWritingAtPath: filePath) {
			output_stream.writeData(data)
			return true
		} else {
			err = NSError(domain: "LocalizerErrDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open file at path \(filePath) for writing"])
			return false
		}
	} else {
		err = NSError(domain: "LocalizerErrDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot convert text to expected encoding"])
		return false
	}
}

switch argAtIndexOrExit(1, "Command is required") {
	/* Export from Xcode */
	case "export_from_xcode":
		var i = 2
		
		var excluded_paths = [String]()
		i = getLongArgs(i, ["exclude": {(value: String) in excluded_paths.append(value)}])
		
		let root_folder = argAtIndexOrExit(i++, "Root folder is required")
		var output = argAtIndexOrExit(i++, "Output is required")
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		println("Exporting from Xcode project...")
		
		var err: NSError?
		var got_error = true
		if let parsed_strings_files = XcodeStringsFile.stringsFilesInProject(root_folder, excluded_paths: excluded_paths, err: &err) {
			if let csv = happnCSVLocFile(fromPath: output, error: &err) {
				csv.mergeXcodeStringsFiles(parsed_strings_files, folderNameToLanguageName: folder_name_to_language_name)
				var csvText = ""
				print(csv, &csvText)
				if writeText(csvText, toFile: output, usingEncoding: NSUTF8StringEncoding, &err) {
					got_error = false
				}
			}
		}
		if got_error {
			println("Cannot parse Xcode strings files. Got error \(err)")
			exit(err != nil ? Int32(err!.code) : 255)
		} else {
			exit(0)
		}
	
	/* Import to Xcode */
	case "import_to_xcode":
		println("Importing to Xcode project...")
	
	/* Export from Android */
	case "export_from_android":
		var i = 2
		
		var res_folder = "res"
		var strings_filenames = [String]()
		i = getLongArgs(i, [
			"res-folder":       {(value: String) in res_folder = value},
			"strings-filename": {(value: String) in strings_filenames.append(value)}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let root_folder = argAtIndexOrExit(i++, "Root folder is required")
		let output = argAtIndexOrExit(i++, "Root folder is required")
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		println("Exporting from Android project...")
	
	/* Import to Android */
	case "import_to_android":
		var i = 2
		
		var res_folder = "res"
		var strings_filenames = [String]()
		i = getLongArgs(i, [
			"res-folder":       {(value: String) in res_folder = value},
			"strings-filename": {(value: String) in strings_filenames.append(value)}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let input_path = argAtIndexOrExit(i++, "Input file (CSV) is required")
		let root_folder = argAtIndexOrExit(i++, "Root folder is required")
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		println("Importing to Android project...")
		var err: NSError?;
		if let csv = happnCSVLocFile(fromPath: input_path, error: &err) {
			csv.exportToAndroidProjectWithRoot(root_folder, folderNameToLanguageName: folder_name_to_language_name)
		}
	
	/* Convenient command for debug purposes */
	case "test_xcode_export":
		var err: NSError?;
		if let parsed_strings_files = XcodeStringsFile.stringsFilesInProject("/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/Happn/", excluded_paths: ["Dependencies/", ".git/"], err: &err) {
			if let csv = happnCSVLocFile(fromPath: "/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/ loc.csv", error: &err) {
				csv.mergeXcodeStringsFiles(parsed_strings_files, folderNameToLanguageName: ["en.lproj": "English", "fr.lproj": "Français", "de.lproj": "Deutsch", "es.lproj": "Español", "it.lproj": "Italiano", "pt.lproj": "Português"])
				println("CSV: ")
				print(csv)
			}
		}
	
	/* Convenient command for debug purposes */
	case "test_xcode_import":
		var err: NSError?;
		if let csv = happnCSVLocFile(fromPath: "/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/ loc.csv", error: &err) {
			csv.exportToXcodeProjectWithRoot("/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/Happn/", folderNameToLanguageName: ["en.lproj": "English", "fr.lproj": "Français", "de.lproj": "Deutsch", "es.lproj": "Español", "it.lproj": "Italiano"/*, "pt.lproj": "Português"*/])
		}
	
	/* Convenient command for debug purposes */
	case "test_android_export":
		var err: NSError?;
		if let parsed_loc_files = AndroidXMLLocFile.locFilesInProject("/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/HappnAndroid/", resFolder: "happn-android/Happn/src/main/res", stringsFilenames: ["strings.xml"], languageFolderNames: ["values", "values-de", "values-es", "values-fr"], err: &err) {
			if let csv = happnCSVLocFile(fromPath: "/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/ loc.csv", error: &err) {
				csv.mergeAndroidXMLLocStringsFiles(parsed_loc_files, folderNameToLanguageName: ["values": "English", "values-fr": "Français", "values-de": "Deutsch", "values-es": "Español", "values-it": "Italiano", "values-pt": "Português"])
				println("CSV: ")
				print(csv)
			}
		}
	
	/* Convenient command for debug purposes */
	case "test_android_import":
		var err: NSError?;
		if let csv = happnCSVLocFile(fromPath: "/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/ loc.csv", error: &err) {
			csv.exportToAndroidProjectWithRoot("/Volumes/Frizlab HD/Users/frizlab/Work/Doing/FTW and Co/HappnAndroid/", folderNameToLanguageName: ["values": "English", "values-fr": "Français", "values-de": "Deutsch", "values-es": "Español"/*, "values-it": "Italiano", "values-pt": "Português"*/])
		}
	
	default:
		println("Unknown command \(Process.arguments[1])", &mx_stderr)
		usage(Process.arguments[0], &mx_stderr)
		exit(2)
}
