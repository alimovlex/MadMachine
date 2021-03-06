//
//  BuildCommand.swift
//  MadMachineCli
//
//  Created by Tibor Bodecs on 2020. 10. 02..
//

import Foundation
import ConsoleKit
import PathKit
import MadMachine

final class BuildCommand: Command {
    
    enum BinaryType: String {
        case library
        case executable
    }

    static let name = "build"
    
    /*
     swift run MadMachineCli build \
     --name SwiftIO \
     --input ../SwiftIO \
     --output ./SwiftIO \
     --import-headers ../SwiftIO/Sources/CHal/include/SwiftHalWrapper.h \
     --import-search-paths ./,../ \
     --verbose
     */
    struct Signature: CommandSignature {
        
        @Option(name: "name", short: "n", help: "Name of the build product")
        var name: String?
        
        @Option(name: "binary-type", short: "b", help: "Binary type (library or executable)")
        var binaryType: String?
        
        @Option(name: "input", short: "i", help: "Location of the project to build")
        var input: String?
        
        @Option(name: "output", short: "o", help: "Path to the MadMachine Toolchain")
        var output: String?
        
        @Option(name: "toolchain", short: "t", help: "Path to the MadMachine Toolchain")
        var toolchain: String?
        
        @Option(name: "library", short: "l", help: "Path to the MadMachine System Library")
        var library: String?
        
        @Option(name: "import-headers", short: "h", help: "Headers to import (use a coma separated list)")
        var importHeaders: String?
        
        @Option(name: "import-search-paths", short: "p", help: "Paths to import (use a coma separated list)")
        var importSearchPaths: String?
        
        @Flag(name: "verbose", short: "v", help: "Verbose output")
        var verbose: Bool
    }
        
    let help = "MadMachine project executable and library builder"

    func run(using context: CommandContext, signature: Signature) throws {
        let n = signature.name ?? Path.current.basename
        
        var b = BinaryType.library
        if let rawBinaryType = signature.binaryType, let customBinaryType = BinaryType(rawValue: rawBinaryType) {
            b = customBinaryType
        }

        var i = Path.current.location
        if let customInput = signature.input {
            i = customInput.resolvedPath
        }
        var o = Path.current.location
        if let customOutput = signature.output {
            o = customOutput.resolvedPath
        }
        var t = MadMachine.Paths.toolchain.location
        if let customToolchain = signature.toolchain {
            t = customToolchain.resolvedPath
        }
        var l = MadMachine.Paths.lib.location
        if let customLibrary = signature.library {
            l = customLibrary.resolvedPath
        }
        var h: [String] = []
        if let customImportHeaders = signature.importHeaders {
            h = customImportHeaders.split(separator: ",").map(String.init).map(\.resolvedPath)
        }
        var p: [String] = []
        if let customImportSearchPaths = signature.importSearchPaths {
            p = customImportSearchPaths.split(separator: ",").map(String.init).map(\.resolvedPath)
        }
                
        let mm = try MadMachine(toolchainLocation: t, libLocation: l)

        if signature.verbose {
            let info = """
            MadMachine:
                Toolchain: `\(t)`
                Library: `\(l)`
            
            Project:
                Name: `\(n)`
                Binary type: `\(b.rawValue)`
                Input: `\(i)`
                Output: `\(o)`
                Import Headers:
                    \(h.map({ "`\($0)`" }).joined(separator: "\n            "))
                Import Search Paths:
                    \(p.map({ "`\($0)`" }).joined(separator: "\n            "))
            """
            context.console.info(info)
        }
        
        let progressBar = context.console.progressBar(title: "Building `\(n)` \(b.rawValue)")
        progressBar.start()

        var logs: [String] = []
        do {
            switch b {
            case .library:
                try mm.buildLibrary(name: n, input: i, output: o, importHeaders: h, importSearchPaths: p) { progress, log in
                    progressBar.activity.currentProgress = progress
                    logs.append(log)
                }
            case .executable:
                try mm.buildExecutable(name: n, input: i, output: o, importHeaders: h, importSearchPaths: p) { progress, log in
                    progressBar.activity.currentProgress = progress
                    logs.append(log)
                }
            }
            progressBar.succeed()
        }
        catch {
            progressBar.fail()
            context.console.error(error.localizedDescription)
        }
        if signature.verbose {
            context.console.info(logs.joined(separator: "\n\n"))
        }
    }
}
