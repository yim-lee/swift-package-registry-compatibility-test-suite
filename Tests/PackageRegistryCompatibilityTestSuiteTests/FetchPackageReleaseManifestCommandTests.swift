//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import XCTest

import PackageRegistryClient
@testable import PackageRegistryCompatibilityTestSuite
import TSCBasic

final class FetchPackageReleaseManifestCommandTests: XCTestCase {
    private var sourceArchives: [SourceArchiveMetadata]!
    private var registryClient: PackageRegistryClient!

    override func setUp() {
        do {
            let archivesJSON = self.fixtureURL(subdirectory: "SourceArchives", filename: "source_archives.json")
            self.sourceArchives = try JSONDecoder().decode([SourceArchiveMetadata].self, from: Data(contentsOf: archivesJSON))
        } catch {
            XCTFail("Failed to load source_archives.json")
        }

        let clientConfiguration = PackageRegistryClient.Configuration(url: self.registryURL, defaultRequestTimeout: .seconds(1))
        self.registryClient = PackageRegistryClient(httpClientProvider: .createNew, configuration: clientConfiguration)
    }

    override func tearDown() {
        try! self.registryClient.syncShutdown()
    }

    func test_help() throws {
        XCTAssert(try executeCommand(command: "package-registry-compatibility fetch-package-release-manifest --help")
            .stdout.contains("USAGE: package-registry-compatibility fetch-package-release-manifest <url> <config-path>"))
    }

    func test_run() throws {
        // Create package releases
        let scope = "sunshinejr-\(UUID().uuidString.prefix(6))"
        let name = "SwiftyUserDefaults"
        let versions = ["5.3.0"]
        self.createPackageReleases(scope: scope, name: name, versions: versions, client: self.registryClient, sourceArchives: self.sourceArchives)

        let unknownScope = "test-\(UUID().uuidString.prefix(6))"

        let config = PackageRegistryCompatibilityTestSuite.Configuration(
            fetchPackageReleaseManifest: FetchPackageReleaseManifestTests.Configuration(
                packageReleases: [
                    .init(
                        packageRelease: PackageRelease(package: PackageIdentity(scope: scope, name: name), version: "5.3.0"),
                        swiftVersions: ["4.2"],
                        noSwiftVersions: ["5.0"]
                    ),
                ],
                unknownPackageReleases: [PackageRelease(package: PackageIdentity(scope: unknownScope, name: "unknown"), version: "1.0.0")],
                contentLengthHeaderIsSet: true,
                contentDispositionHeaderIsSet: true,
                linkHeaderHasAlternateRelations: true
            )
        )
        let configData = try JSONEncoder().encode(config)

        try withTemporaryDirectory(removeTreeOnDeinit: true) { directoryPath in
            let configPath = directoryPath.appending(component: "config.json")
            try localFileSystem.writeFileContents(configPath, bytes: ByteString(Array(configData)))

            XCTAssert(try self.executeCommand(subcommand: "fetch-package-release-manifest", configPath: configPath.pathString, generateData: false)
                .stdout.contains("Fetch Package Release Manifest - All tests passed."))
        }
    }

    func test_run_generateConfig() throws {
        let configPath = self.fixturePath(filename: "gendata.json")
        XCTAssert(try self.executeCommand(subcommand: "fetch-package-release-manifest", configPath: configPath, generateData: true)
            .stdout.contains("Fetch Package Release Manifest - All tests passed."))
    }
}
