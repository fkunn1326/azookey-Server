// デフォルト辞書つきの変換モジュールをインポート
import KanaKanjiConverterModuleWithDefaultDictionary
import Foundation
import WinSDK

func convertToWideString(_ string: String) -> [WCHAR] {
    return string.utf16.map { WCHAR($0) } + [0]
}


// 変換器を初期化する
let converter = KanaKanjiConverter()
// 入力を初期化する
var composing_text = ComposingText()
// 変換したい文章を追加する
let options = ConvertRequestOptions.withDefaultDictionary(
    // 日本語予測変換
    requireJapanesePrediction: true,
    // 英語予測変換 
    requireEnglishPrediction: false,
    // 入力言語 
    keyboardLanguage: .ja_JP,
    // 学習タイプ 
    learningType: .nothing, 
    // 学習データを保存するディレクトリのURL（書類フォルダを指定）
    memoryDirectoryURL: URL.init(filePath: "./test"),
    // ユーザ辞書データのあるディレクトリのURL（書類フォルダを指定）
    sharedContainerURL: URL.init(filePath: "./test"),

    // zenzai
    // zenzaiMode: .on(
    //     weight: URL.init(filePath: "./zenz-v2-Q5_K_M.gguf"),
    //     inferenceLimit: 1,
    //     requestRichCandidates: true,
    //     versionDependentMode: .v2(
    //         .init(
    //             profile: "鈴木花子",
    //             leftSideContext: ""
    //         )
    //     )
    // ),
    // メタデータ
    metadata: .init(versionString: "You App Version X")
)

let pipeName = "\\\\.\\pipe\\azookey_service"
var pipeNameWide = convertToWideString(pipeName)

let pipeHandle = CreateNamedPipeW(
    &pipeNameWide,
    DWORD(PIPE_ACCESS_DUPLEX),
    DWORD(PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT),
    UINT32(PIPE_UNLIMITED_INSTANCES),
    1024,
    1024,
    0,
    nil
)

@MainActor
func waitForConnection() {
    print("Waiting for client connection...")
    let connected = ConnectNamedPipe(pipeHandle, nil)
    if !connected {
        let error = GetLastError()
        if error != ERROR_PIPE_CONNECTED {
            print("ConnectNamedPipe failed. Error: \(error)")
            return
        }
    }
    print("Client connected. Starting communication...")
}

@MainActor
func receive() -> String {
    var buffer = [UInt8](repeating: 0, count: 1024)
    var bytesRead: DWORD = 0
    let _ = ReadFile(
        pipeHandle,
        &buffer,
        DWORD(buffer.count),
        &bytesRead,
        nil
    )
    return String(decoding: buffer.prefix(Int(bytesRead)), as: UTF8.self)
}

@MainActor
func send(_ received: String) {
    let message = received
    var bytesWritten: DWORD = 0
    let _ = WriteFile(
        pipeHandle,
        message,
        DWORD(message.utf8.count),
        &bytesWritten,
        nil
    )
    FlushFileBuffers(pipeHandle)
    print("Sent: \(message)")
}

@MainActor
func disconnectAndReconnect() {
    DisconnectNamedPipe(pipeHandle)
    waitForConnection()
}

// Initial connection
waitForConnection()

// Communication loop
while true {
    let receivedMessage = receive()
    if receivedMessage.isEmpty {
        print("Client disconnected or error occurred.")
        disconnectAndReconnect()
        continue
    }

    composing_text.insertAtCursorPosition(receivedMessage, inputStyle: .roman2kana)
    let results = converter.requestCandidates(composing_text, options: options)
    send(results.mainResults.first!.text)
}