import Foundation
import CryptoKit

// Fail publication if the feed does not describe and authenticate the built ZIP.
do {
    guard CommandLine.arguments.count == 5 else {
        throw NSError(domain: "Appcast", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected appcast, ZIP, Info.plist and download URL"])
    }
    let args = CommandLine.arguments
    let xml = try XMLDocument(contentsOf: URL(fileURLWithPath: args[1]))
    let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: args[3])), format: nil) as! [String: Any]
    let archive = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    let items = try xml.nodes(forXPath: "/rss/channel/item")
    guard items.count == 1, let item = items.first as? XMLElement,
          let enclosure = item.elements(forName: "enclosure").first,
          enclosure.attribute(forName: "url")?.stringValue == args[4],
          enclosure.attribute(forName: "length")?.stringValue == String(archive.count),
          item.elements(forLocalName: "version", uri: "http://www.andymatuschak.org/xml-namespaces/sparkle").first?.stringValue == plist["CFBundleVersion"] as? String,
          item.elements(forLocalName: "shortVersionString", uri: "http://www.andymatuschak.org/xml-namespaces/sparkle").first?.stringValue == plist["CFBundleShortVersionString"] as? String,
          let signatureText = enclosure.attribute(forLocalName: "edSignature", uri: "http://www.andymatuschak.org/xml-namespaces/sparkle")?.stringValue,
          let signature = Data(base64Encoded: signatureText),
          let publicText = plist["SUPublicEDKey"] as? String,
          let publicData = Data(base64Encoded: publicText),
          try Curve25519.Signing.PublicKey(rawRepresentation: publicData).isValidSignature(signature, for: archive) else {
        throw NSError(domain: "Appcast", code: 2, userInfo: [NSLocalizedDescriptionKey: "Appcast metadata or Ed25519 signature does not match the built application"])
    }
    print("PASS: appcast version, URL, archive length and signature match the built application")
} catch {
    fputs("Appcast validation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
