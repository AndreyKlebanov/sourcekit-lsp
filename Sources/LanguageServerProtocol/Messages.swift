//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basic

/// The set of known requests.
///
/// All requests from LSP as well as any extensions provided by the server should be listed here. If you are adding a message for testing only, you can register it dynamically using `MessageRegistry._register()` which allows you to avoid bloating the real server implementation.
public let builtinRequests: [_RequestType.Type] = [
  InitializeRequest.self,
  Shutdown.self,
  WorkspaceFoldersRequest.self,
  CompletionRequest.self,
  HoverRequest.self,
  DefinitionRequest.self,
  ReferencesRequest.self,
  DocumentHighlightRequest.self,
  DocumentFormatting.self,
  DocumentRangeFormatting.self,
  DocumentOnTypeFormatting.self,

  // MARK: LSP Extension Requests

  SymbolInfoRequest.self,
]

/// The set of known notifications.
///
/// All notifications from LSP as well as any extensions provided by the server should be listed here. If you are adding a message for testing only, you can register it dynamically using `MessageRegistry._register()` which allows you to avoid bloating the real server implementation.
public let builtinNotifications: [NotificationType.Type] = [
  InitializedNotification.self,
  Exit.self,
  CancelRequest.self,
  LogMessage.self,
  DidChangeConfiguration.self,
  DidChangeWorkspaceFolders.self,
  DidOpenTextDocument.self,
  DidCloseTextDocument.self,
  DidChangeTextDocument.self,
  DidSaveTextDocument.self,
  WillSaveTextDocument.self,
  PublishDiagnostics.self,
]

// MARK: - General -

public struct InitializeRequest: RequestType, Hashable {
  public static let method: String = "initialize"
  public typealias Response = InitializeResult

  /// The process identifier (pid) of the process that started the LSP server, or nil if the server was started by e.g. a user shell and should not be monitored.
  ///
  /// If the client process dies, the server should exit.
  public var processId: Int? = nil

  /// The workspace path, or nil if no workspace is open.
  ///
  /// - Note: deprecated in favour of `rootURL`.
  public var rootPath: String? = nil

  /// The workspace URL, or nil if no workspace is open.
  ///
  /// Takes precedence over the deprecated `rootPath`.
  public var rootURL: URL?

  /// Any user-provided options.
  public var initializationOptions: InitializationOptions? = nil

  /// The capabilities provided by the client editor.
  public var capabilities: ClientCapabilities

  public enum Tracing: String, Codable  {
    case off
    case messages
    case verbose
  }

  /// Whether to enable tracing.
  public var trace: Tracing? = .off

  /// The workspace folders configued, if the client supports multiple workspace folders.
  public var workspaceFolders: [WorkspaceFolder]?

  public init(processId: Int? = nil, rootPath: String? = nil, rootURL: URL?, initializationOptions: InitializationOptions? = nil, capabilities: ClientCapabilities, trace: Tracing = .off, workspaceFolders: [WorkspaceFolder]?) {
    self.processId = processId
    self.rootPath = rootPath
    self.rootURL = rootURL
    self.initializationOptions = initializationOptions
    self.capabilities = capabilities
    self.trace = trace
    self.workspaceFolders = workspaceFolders
  }
}

extension InitializeRequest: Codable {
  private enum CodingKeys: String, CodingKey {
    case processId
    case rootPath
    case rootURL = "rootUri"
    case initializationOptions
    case capabilities
    case trace
    case workspaceFolders
  }
}

public struct InitializeResult: ResponseType, Hashable {

  /// The capabilities of the language server.
  public var capabilities: ServerCapabilities

  public init(capabilities: ServerCapabilities) {
    self.capabilities = capabilities
  }
}

public struct InitializedNotification: NotificationType, Hashable {
  public static let method: String = "initialized"

  public init() {}
}

public struct CancelRequest: NotificationType, Hashable {
  public static let method: String = "$/cancelRequest"

  /// The request to cancel.
  public var id: RequestID

  public init(id: RequestID) {
    self.id = id
  }
}

public struct VoidResponse: ResponseType, Hashable {
  public init() {}
}

extension Optional: MessageType where Wrapped: MessageType {}
extension Optional: ResponseType where Wrapped: ResponseType {}

extension Array: MessageType where Element: MessageType {}
extension Array: ResponseType where Element: ResponseType {}

public struct Shutdown: RequestType, Hashable {
  public static let method: String = "shutdown"
  public typealias Response = VoidResponse
}

public struct Exit: NotificationType, Hashable {
  public static let method: String = "exit"
}

public protocol TextDocumentRequest: RequestType {

  var textDocument: TextDocumentIdentifier { get }
}
