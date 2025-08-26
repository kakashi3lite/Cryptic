//
//  DraftPreviewView.swift
//  Cryptic
//
//  Presents encoded output and sharing affordances.
//

import SwiftUI

struct DraftPreviewView: View {
    let result: EncodeResult
    @State private var protect = false
    @State private var passphrase: String = ""
    @State private var encryptedData: Data? = nil

    var body: some View {
        VStack(spacing: 16) {
            switch result.artifact {
            case .text(let s):
                ScrollView { Text(s).textSelection(.enabled).padding() }
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .image(let img):
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            case .data(let data):
                Text("Data size: \(data.count) bytes")
            }

            HStack {
                Text(result.description).foregroundStyle(.secondary)
                Spacer()
                shareView
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $protect) { Text("Protect with passphrase") }
                if protect {
                    SecureField("Enter passphrase", text: $passphrase)
                        .textContentType(.newPassword)
                        .onChange(of: passphrase) { _, _ in refreshEnvelope() }
                    Text("Encrypted as .cryptic JSON envelope (ChaChaPoly)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    @ViewBuilder private var shareView: some View {
        if protect {
            let item = encryptedData ?? Data()
            ShareLink("Share", item: item, preview: SharePreview("Encrypted (.cryptic)", icon: Image(systemName: "lock.shield")))
                .disabled(passphrase.isEmpty || encryptedData == nil)
        } else {
            switch result.artifact {
            case .text(let s):
                ShareLink("Share", item: s)
            case .image(let img):
                ShareLink("Share", item: Image(uiImage: img), preview: SharePreview("Encoded Image", image: Image(uiImage: img)))
            case .data(let data):
                ShareLink("Share", item: data)
            }
        }
    }

    private func refreshEnvelope() {
        guard protect, !passphrase.isEmpty else { encryptedData = nil; return }
        if let plain = plainData(from: result.artifact) {
            encryptedData = try? CrypticEnvelope.encrypt(plain, passphrase: passphrase)
        } else {
            encryptedData = nil
        }
    }

    private func plainData(from artifact: EncodeArtifact) -> Data? {
        switch artifact {
        case .text(let s):
            return Data(s.utf8)
        case .image(let image):
            return image.pngData()
        case .data(let d):
            return d
        }
    }
}

#Preview {
    DraftPreviewView(result: EncodeResult(artifact: .text("😀🌟 test"), description: "Emoji substitution"))
}
