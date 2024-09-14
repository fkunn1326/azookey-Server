import KanaKanjiConverterModuleWithDefaultDictionary
import Foundation
import WinSDK

let PIPE_NAME = "\\\\.\\pipe\\azookey_service"
let BUFFER_SIZE: DWORD = 1024

var leftSideContext = ""

func convertToWideString(_ string: String) -> [WCHAR] {
    return string.utf16.map { WCHAR($0) } + [0]
}

// 名前付きパイプようのクラス

class PipeHandler {
    private let pipeHandle: HANDLE
    
    @MainActor
    init() {
        var pipeNameWide = convertToWideString(PIPE_NAME)
        pipeHandle = CreateNamedPipeW(
            &pipeNameWide,
            DWORD(PIPE_ACCESS_DUPLEX),
            DWORD(PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT),
            1,
            BUFFER_SIZE,
            BUFFER_SIZE,
            0,
            nil
        )
        
        if pipeHandle == INVALID_HANDLE_VALUE {
            fatalError("Failed to create named pipe. Error: \(GetLastError())")
        }
    }
    
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
    
    func receive() -> String {
        var buffer = [UInt8](repeating: 0, count: Int(BUFFER_SIZE))
        var bytesRead: DWORD = 0
        let success = ReadFile(
            pipeHandle,
            &buffer,
            BUFFER_SIZE,
            &bytesRead,
            nil
        )
        
        if !success {
            print("Failed to read from pipe. Error: \(GetLastError())")
            return ""
        }
        
        return String(decoding: buffer.prefix(Int(bytesRead)), as: UTF8.self)
    }
    
    func send(_ message: String) {
        var bytesWritten: DWORD = 0
        let success = WriteFile(
            pipeHandle,
            message,
            DWORD(message.utf8.count),
            &bytesWritten,
            nil
        )
        
        if !success {
            print("Failed to write to pipe. Error: \(GetLastError())")
            return
        }
        
        FlushFileBuffers(pipeHandle)
        // print("Sent: \(message)")
    }
    
    func disconnect() {
        DisconnectNamedPipe(pipeHandle)
    }
}

// 変換クラス

class ConversionHandler {
    private let converter: KanaKanjiConverter
    private var composingText: ComposingText
    
    @MainActor
    init() {
        converter = KanaKanjiConverter()
        composingText = ComposingText()
    }
    
    private static func createConvertRequestOptions(leftSideContext: String) -> ConvertRequestOptions {
        return ConvertRequestOptions.withDefaultDictionary(
            requireJapanesePrediction: true,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: URL(filePath: "./test"),
            sharedContainerURL: URL(filePath: "./test"),
            // zenzai
            zenzaiMode: .on(
                weight: URL.init(filePath: "C:/Users/WDAGUtilityAccount/Desktop/Service/zenz-v2-Q5_K_M.gguf"),
                inferenceLimit: 1,
                requestRichCandidates: true,
                versionDependentMode: .v2(
                    .init(
                        profile: "",
                        leftSideContext: leftSideContext
                    )
                )
            ),
            metadata: .init(versionString: "Your App Version X"),
        )
    }
    
    @MainActor
    func insert(_ input: String) {
        composingText.insertAtCursorPosition(input, inputStyle: .roman2kana)
    }

    @MainActor
    func delete() {
        composingText.deleteBackwardFromCursorPosition(count: 1)
    }

    @MainActor
    func getConvertedList() -> [String] {
        let hiragana = composingText.convertTarget
        let converted = converter.requestCandidates(composingText, options: ConversionHandler.createConvertRequestOptions(leftSideContext: leftSideContext))
        var result: [String] = []

        guard let candidate = converted.mainResults.first else {
            return [hiragana]
        }

        let candidateCount = candidate.data.reduce(0) { $0 + $1.ruby.count }
        let hiraganaCount = hiragana.count
        
        if candidateCount > hiraganaCount {
            result.append(constructCandidateString(candidate: candidate, hiragana: hiragana))
        } else {
            result.append(candidate.text)
        }
        
        // 2個目以降の候補を追加
        for i in 1..<converted.mainResults.count {
            let candidate = converted.mainResults[i]
            result.append(candidate.text)
        }

        if result.count < 5 {
            for _ in 0..<(5 - result.count) {
                result.append("")
            }
        }

        return result
    }
    
    private func constructCandidateString(candidate: Candidate, hiragana: String) -> String {
        var remainingHiragana = hiragana
        var result = ""
        
        for data in candidate.data {
            if remainingHiragana.count < data.ruby.count {
                result += remainingHiragana
                break
            }
            remainingHiragana.removeFirst(data.ruby.count)
            result += data.word
        }
        
        return result
    }
    
    func resetComposingText() {
        composingText = ComposingText()
    }
}

// MARK: - KanaKanjiConverterService Class

class KanaKanjiConverterService {
    private let pipeHandler: PipeHandler
    private let conversionHandler: ConversionHandler
    
    @MainActor
    init() {
        pipeHandler = PipeHandler()
        conversionHandler = ConversionHandler()
    }
    
    @MainActor
    func start() {
        pipeHandler.waitForConnection()
        
        while true {
            let receivedMessage = pipeHandler.receive()
            if receivedMessage.isEmpty {
                print("Client disconnected or error occurred.")
                handleDisconnection()
                continue
            }

            // read json
            let jsonData = receivedMessage.data(using: .utf8)!
            let json = try! JSONSerialization.jsonObject(with: jsonData) as! [String: String]
            let type = json["type"] as! String
            let message = json["message"] as! String

            if type == "key" {
                let message = Int(message)!
                let code = Int32(message)
                switch code {
                    case VK_BACK:
                        conversionHandler.delete()
                    case (0x30...0x5A):
                        conversionHandler.insert(String(UnicodeScalar(Int(code))!).lowercased())
                    case VK_OEM_MINUS:
                        conversionHandler.insert("ー")
                    case VK_OEM_COMMA:
                        conversionHandler.insert("、")
                    case VK_OEM_PERIOD:
                        conversionHandler.insert("。")
                    default:
                        break
                }
                
                let convertedList = conversionHandler.getConvertedList()

                pipeHandler.send(convertedList.joined(separator: ","))
            } else if type == "debug" {
                print(message)
            } else if type == "left" {
                leftSideContext = message
            }
        }
    }
    
    private func handleDisconnection() {
        pipeHandler.disconnect()
        conversionHandler.resetComposingText()
        pipeHandler.waitForConnection()
    }
}

// MARK: - Main Execution
let service = KanaKanjiConverterService()
service.start()