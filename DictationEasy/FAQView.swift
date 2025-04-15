import SwiftUI

struct FAQView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why can't I hear the playback? 為什麼我聽不到播放？")
                            .font(.headline)
                        Text("Ensure your device's silent mode is off (check the side switch) and the volume is turned up. If the issue persists, verify that a voice is downloaded for the selected language in Settings > Accessibility > Spoken Content > Voices. 請確保您的設備未處於靜音模式（檢查側邊開關）並且音量已調高。如果問題仍然存在，請確認在設置 > 輔助功能 > 語音內容 > 語音中已下載所選語言的語音。")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why Mandarin or Cantonese is not played when I choose them? 為什麼我選擇普通話或粵語時未播放相應語言？")
                            .font(.headline)
                        Text("The playback language depends on the voice selected in your device's Settings > Accessibility > Spoken Content > Voices. If you choose Mandarin but Cantonese plays, check that a Mandarin voice (e.g., Tingting for zh-CN) is set, not Cantonese (e.g., Sin-ji for zh-HK), and vice versa. Ensure the correct voice is downloaded. 播放語言取決於您設備在設置 > 輔助功能 > 語音內容 > 語音中選擇的語音。如果您選擇普通話但播放粵語，請檢查是否設置了普通話語音（例如，zh-CN的Tingting）而不是粵語（例如，zh-HK的Sin-ji），反之亦然。請確保已下載正確的語音。")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Frequently Asked Questions 常見問題")
                }
            }
            .padding(.horizontal)
            .navigationTitle("FAQ 常見問題")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FAQView()
}
