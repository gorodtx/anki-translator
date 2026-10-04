import Foundation
import Security

// The encrypted PKCS#12 password stays in the process environment, never argv.
guard CommandLine.arguments.count == 3,
      let password = ProcessInfo.processInfo.environment["CERT_PASSWORD"] else {
    fputs("Certificate file, keychain and CERT_PASSWORD are required.\n", stderr)
    exit(1)
}
var keychain: SecKeychain?
let opened = SecKeychainOpen(CommandLine.arguments[2], &keychain)
guard opened == errSecSuccess, let keychain else {
    fputs("Unable to open temporary signing keychain (\(opened)).\n", stderr)
    exit(1)
}
do {
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let options = [kSecImportExportPassphrase as String: password,
                   kSecImportExportKeychain as String: keychain] as [String: Any]
    var imported: CFArray?
    let status = SecPKCS12Import(data as CFData, options as CFDictionary, &imported)
    guard status == errSecSuccess else {
        fputs("Unable to import signing identity (\(status)).\n", stderr)
        exit(1)
    }
    print("Signing identity imported into temporary keychain.")
} catch {
    fputs("Unable to read PKCS#12 input.\n", stderr)
    exit(1)
}
