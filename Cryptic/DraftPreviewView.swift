//
//  DraftPreviewView.swift
//  Cryptic
//
//  Presents encoded output and sharing affordances.
//

import SwiftUI

struct DraftPreviewView: View {
    let result: EncodeResult

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
        }
        .padding()
    }

    @ViewBuilder private var shareView: some View {
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

#Preview {
    DraftPreviewView(result: EncodeResult(artifact: .text("😀🌟 test"), description: "Emoji substitution"))
}

