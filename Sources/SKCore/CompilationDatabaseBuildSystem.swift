//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import BuildServerProtocol
import LanguageServerProtocol
import LSPLogging
import SKSupport
import Dispatch
import struct Foundation.URL

import protocol TSCBasic.FileSystem
import struct TSCBasic.AbsolutePath
import var TSCBasic.localFileSystem

/// A `BuildSystem` based on loading clang-compatible compilation database(s).
///
/// Provides build settings from a `CompilationDatabase` found by searching a project. For now, only
/// one compilation database, located at the project root.
public actor CompilationDatabaseBuildSystem {
  /// The compilation database.
  var compdb: CompilationDatabase? = nil {
    didSet {
      // Build settings have changed and thus the index store path might have changed.
      // Recompute it on demand.
      _indexStorePath = nil
    }
  }

  /// Delegate to handle any build system events.
  public weak var delegate: BuildSystemDelegate? = nil

  public func setDelegate(_ delegate: BuildSystemDelegate?) async {
    self.delegate = delegate
  }

  let projectRoot: AbsolutePath?

  let fileSystem: FileSystem

  /// The URIs for which the delegate has registered for change notifications,
  /// mapped to the language the delegate specified when registering for change notifications.
  var watchedFiles: [DocumentURI: Language] = [:]

  private var _indexStorePath: AbsolutePath?
  public var indexStorePath: AbsolutePath? {
    if let indexStorePath = _indexStorePath {
      return indexStorePath
    }

    if let allCommands = self.compdb?.allCommands {
      for command in allCommands {
        let args = command.commandLine
        for i in args.indices.reversed() {
          if args[i] == "-index-store-path" && i != args.endIndex - 1 {
            _indexStorePath = try? AbsolutePath(validating: args[i+1])
            return _indexStorePath
          }
        }
      }
    }
    return nil
  }

  public init(projectRoot: AbsolutePath? = nil, fileSystem: FileSystem = localFileSystem) {
    self.fileSystem = fileSystem
    self.projectRoot = projectRoot
    if let path = projectRoot {
      self.compdb = tryLoadCompilationDatabase(directory: path, fileSystem)
    }
  }
}

extension CompilationDatabaseBuildSystem: BuildSystem {

  public var indexDatabasePath: AbsolutePath? {
    indexStorePath?.parentDirectory.appending(component: "IndexDatabase")
  }

  public var indexPrefixMappings: [PathPrefixMapping] { return [] }

  public func buildSettings(for document: DocumentURI, language: Language) async -> FileBuildSettings? {
    guard let url = document.fileURL else {
      // We can't determine build settings for non-file URIs.
      return nil
    }
    guard let db = database(for: url),
          let cmd = db[url].first else { return nil }
    return FileBuildSettings(
      compilerArguments: Array(cmd.commandLine.dropFirst()),
      workingDirectory: cmd.directory)
  }

  public func registerForChangeNotifications(for uri: DocumentURI, language: Language) async {
    self.watchedFiles[uri] = language
  }

  /// We don't support change watching.
  public func unregisterForChangeNotifications(for uri: DocumentURI) {
    self.watchedFiles[uri] = nil
  }

  private func database(for url: URL) -> CompilationDatabase? {
    if let path = try? AbsolutePath(validating: url.path) {
      return database(for: path)
    }
    return compdb
  }

  private func database(for path: AbsolutePath) -> CompilationDatabase? {
    if compdb == nil {
      var dir = path
      while !dir.isRoot {
        dir = dir.parentDirectory
        if let db = tryLoadCompilationDatabase(directory: dir, fileSystem) {
          compdb = db
          break
        }
      }
    }

    if compdb == nil {
      log("could not open compilation database for \(path)", level: .warning)
    }

    return compdb
  }

  private func fileEventShouldTriggerCompilationDatabaseReload(event: FileEvent) -> Bool {
    switch event.uri.fileURL?.lastPathComponent {
    case "compile_commands.json", "compile_flags.txt":
      return true
    default:
      return false
    }
  }

  /// The compilation database has been changed on disk.
  /// Reload it and notify the delegate about build setting changes.
  private func reloadCompilationDatabase() async {
    guard let projectRoot = self.projectRoot else { return }

    self.compdb = tryLoadCompilationDatabase(directory: projectRoot, self.fileSystem)

    if let delegate = self.delegate {
      var changedFiles = Set<DocumentURI>()
      for (uri, _) in self.watchedFiles {
        changedFiles.insert(uri)
      }
      await delegate.fileBuildSettingsChanged(changedFiles)
    }
  }

  public func filesDidChange(_ events: [FileEvent]) async {
    if events.contains(where: { self.fileEventShouldTriggerCompilationDatabaseReload(event: $0) }) {
      await self.reloadCompilationDatabase()
    }
  }

  public func fileHandlingCapability(for uri: DocumentURI) -> FileHandlingCapability {
    guard let fileUrl = uri.fileURL else {
      return .unhandled
    }
    if database(for: fileUrl) != nil {
      return .handled
    } else {
      return .unhandled
    }
  }
}
