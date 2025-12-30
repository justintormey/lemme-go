import Foundation
import CoreNFC

class NFCManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var scannedChipId: String?
    @Published var errorMessage: String?

    private var session: NFCTagReaderSession?
    private var onChipDetected: ((String) -> Void)?

    override init() {
        super.init()
    }

    func startScanning(onChipDetected: @escaping (String) -> Void) {
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }

        self.onChipDetected = onChipDetected
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self)
        session?.alertMessage = "Hold your phone near the NFC chip"
        session?.begin()
        isScanning = true
    }

    func stopScanning() {
        session?.invalidate()
        isScanning = false
    }
}

extension NFCManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("NFC session became active")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            if let nfcError = error as? NFCReaderError {
                if nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                    self.errorMessage = "NFC Error: \(error.localizedDescription)"
                }
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }

            var chipId: String?

            switch tag {
            case .iso7816(let iso7816Tag):
                chipId = iso7816Tag.identifier.map { String(format: "%02X", $0) }.joined()
            case .feliCa(let feliCaTag):
                chipId = feliCaTag.currentIDm.map { String(format: "%02X", $0) }.joined()
            case .iso15693(let iso15693Tag):
                chipId = iso15693Tag.identifier.map { String(format: "%02X", $0) }.joined()
            case .miFare(let miFareTag):
                chipId = miFareTag.identifier.map { String(format: "%02X", $0) }.joined()
            @unknown default:
                session.invalidate(errorMessage: "Unsupported tag type")
                return
            }

            if let chipId = chipId {
                session.alertMessage = "Chip detected!"
                DispatchQueue.main.async {
                    self.scannedChipId = chipId
                    self.onChipDetected?(chipId)
                }
                session.invalidate()
            } else {
                session.invalidate(errorMessage: "Could not read chip ID")
            }
        }
    }
}
