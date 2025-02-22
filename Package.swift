// swift-tools-version:5.7

import PackageDescription
import Foundation

// When building the toolchain on the CI, don't add the CI's runpath for the
// final build before installing.
let sourcekitLSPLinkSettings : [LinkerSetting]
if ProcessInfo.processInfo.environment["SOURCEKIT_LSP_CI_INSTALL"] != nil {
  sourcekitLSPLinkSettings = [ .unsafeFlags(["-no-toolchain-stdlib-rpath"], .when(platforms: [.linux, .android])) ]
} else {
  sourcekitLSPLinkSettings = []
}

let package = Package(
    name: "SourceKitLSP",
    platforms: [.macOS("12.0")],
    products: [
      .executable(
        name: "sourcekit-lsp",
        targets: ["sourcekit-lsp"]
      ),
      .library(
        name: "_SourceKitLSP",
        targets: ["SourceKitLSP"]
      ),
      .library(
        name: "LSPBindings",
        targets: [
          "LanguageServerProtocol",
          "LanguageServerProtocolJSONRPC",
        ]
      )
    ],
    dependencies: [
      // See 'Dependencies' below.
    ],
    targets: [
      .executableTarget(
        name: "sourcekit-lsp",
        dependencies: [
          "LanguageServerProtocolJSONRPC",
          "SourceKitLSP",
          .product(name: "ArgumentParser", package: "swift-argument-parser"),
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ],
        exclude: ["CMakeLists.txt"],
        linkerSettings: sourcekitLSPLinkSettings),

      .target(
        name: "SourceKitLSP",
        dependencies: [
          "BuildServerProtocol",
          .product(name: "IndexStoreDB", package: "indexstore-db"),
          "LanguageServerProtocol",
          "LanguageServerProtocolJSONRPC",
          "SKCore",
          "SourceKitD",
          "SKSwiftPMWorkspace",
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
          .product(name: "SwiftSyntax", package: "swift-syntax"),
          .product(name: "SwiftParser", package: "swift-syntax"),
          .product(name: "SwiftIDEUtils", package: "swift-syntax"),
        ],
        exclude: ["CMakeLists.txt"]),

      .target(
        name: "CSKTestSupport",
        dependencies: []),
      .target(
        name: "SKTestSupport",
        dependencies: [
          "CSKTestSupport",
          "LSPTestSupport",
          "SourceKitLSP",
          .product(name: "ISDBTestSupport", package: "indexstore-db"),
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ],
        resources: [
          .copy("INPUTS"),
        ]
      ),
      .testTarget(
        name: "SourceKitLSPTests",
        dependencies: [
          "SKTestSupport",
          "SourceKitLSP",
        ]
      ),

      .target(
        name: "SKSwiftPMWorkspace",
        dependencies: [
          "BuildServerProtocol",
          "LanguageServerProtocol",
          "SKCore",
          .product(name: "SwiftPM-auto", package: "swift-package-manager")
        ],
        exclude: ["CMakeLists.txt"]),

      .testTarget(
        name: "SKSwiftPMWorkspaceTests",
        dependencies: [
          "SKSwiftPMWorkspace",
          "SKTestSupport",
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ]
      ),

      // SKCore: Data structures and algorithms useful across the project, but not necessarily
      // suitable for use in other packages.
      .target(
        name: "SKCore",
        dependencies: [
          "SourceKitD",
          "BuildServerProtocol",
          "LanguageServerProtocol",
          "LanguageServerProtocolJSONRPC",
          "SKSupport",
          .product(name: "SwiftPMDataModel-auto", package: "swift-package-manager"),
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ],
        exclude: ["CMakeLists.txt"]),

      .testTarget(
        name: "SKCoreTests",
        dependencies: [
          "SKCore",
          "SKTestSupport",
        ]
      ),

      // SourceKitD: Swift bindings for sourcekitd.
      .target(
        name: "SourceKitD",
        dependencies: [
          "Csourcekitd",
          "LSPLogging",
          "SKSupport",
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ],
        exclude: ["CMakeLists.txt"]),

      .testTarget(
        name: "SourceKitDTests",
        dependencies: [
          "SourceKitD",
          "SKCore",
          "SKTestSupport",
        ]
      ),

      // Csourcekitd: C modules wrapper for sourcekitd.
      .target(
        name: "Csourcekitd",
        dependencies: [],
        exclude: ["CMakeLists.txt"]),

      // Logging support used in LSP modules.
      .target(
        name: "LSPLogging",
        dependencies: [],
        exclude: ["CMakeLists.txt"]),

      .testTarget(
        name: "LSPLoggingTests",
        dependencies: [
          "LSPLogging",
        ]
      ),

      .target(
        name: "LSPTestSupport",
        dependencies: [
          "LanguageServerProtocol",
          "LanguageServerProtocolJSONRPC"
        ]
      ),

      // jsonrpc: LSP connection using jsonrpc over pipes.
      .target(
        name: "LanguageServerProtocolJSONRPC",
        dependencies: [
          "LanguageServerProtocol",
          "LSPLogging",
        ],
        exclude: ["CMakeLists.txt"]),

      .testTarget(
        name: "LanguageServerProtocolJSONRPCTests",
        dependencies: [
          "LanguageServerProtocolJSONRPC",
          "LSPTestSupport"
        ]
      ),

      // LanguageServerProtocol: The core LSP types, suitable for any LSP implementation.
      .target(
        name: "LanguageServerProtocol",
        dependencies: [
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ],
        exclude: ["CMakeLists.txt"]),

      .testTarget(
        name: "LanguageServerProtocolTests",
        dependencies: [
          "LanguageServerProtocol",
          "LSPTestSupport",
        ]
      ),

      // BuildServerProtocol: connection between build server and language server to provide build and index info
      .target(
        name: "BuildServerProtocol",
        dependencies: [
          "LanguageServerProtocol"
        ],
        exclude: ["CMakeLists.txt"]),

      // SKSupport: Data structures, algorithms and platform-abstraction code that might be generally
      // useful to any Swift package. Similar in spirit to SwiftPM's Basic module.
      .target(
        name: "SKSupport",
        dependencies: [
          .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ],
        exclude: ["CMakeLists.txt"]),

      .testTarget(
        name: "SKSupportTests",
        dependencies: [
          "LSPTestSupport",
          "SKSupport",
          "SKTestSupport",
        ]
      ),
    ]
)

// MARK: Dependencies

// When building with the swift build-script, use local dependencies whose contents are controlled
// by the external environment. This allows sourcekit-lsp to take advantage of the automation used
// for building the swift toolchain, such as `update-checkout`, or cross-repo PR tests.

if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
  let relatedDependenciesBranch = "main"

  // Building standalone.
  package.dependencies += [
    .package(url: "https://github.com/apple/indexstore-db.git", branch: relatedDependenciesBranch),
    .package(url: "https://github.com/apple/swift-package-manager.git", branch: relatedDependenciesBranch),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", branch: relatedDependenciesBranch),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.2"),
    .package(url: "https://github.com/apple/swift-syntax.git", branch: relatedDependenciesBranch),
  ]
} else {
  package.dependencies += [
    .package(path: "../indexstore-db"),
    .package(name: "swift-package-manager", path: "../swiftpm"),
    .package(path: "../swift-tools-support-core"),
    .package(path: "../swift-argument-parser"),
    .package(path: "../swift-syntax")
  ]
}
