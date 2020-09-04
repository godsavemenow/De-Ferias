//
//  ViewController.swift
//  De Férias
//
//  Created by Lucas Silva on 03/09/20.
//  Copyright © 2020 Lucas Silva. All rights reserved.
//

import UIKit
import RealityKit
import Foundation
import AVFoundation
import Speech
    

class ViewController: UIViewController, AVAudioRecorderDelegate {
    
    var session_id:String?
    var semaphore = DispatchSemaphore (value: 0)
    var watsonResponse:String?
    var recordButton: UIButton!
    let notRecording = UIImage(named: "notRecording")
    let Recording = UIImage(named: "Recording")
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var audioFilename:URL!
    
    @IBOutlet var arView: ARView!
    var anchor = try! Sea.loadCena()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        requestTranscribePermissions()
        micPermission()
        self.semaphore = DispatchSemaphore (value: 0)
        openSession(semaphore: self.semaphore)
        semaphore.wait()
        
        arView.scene.anchors.append(anchor)
    }

    func micPermission(){
        
        recordingSession = AVAudioSession.sharedInstance()
                   
        do {
           try recordingSession.setCategory(.playAndRecord, mode: .default)
           try recordingSession.setActive(true)
           recordingSession.requestRecordPermission() { [unowned self] allowed in
               DispatchQueue.main.async {
                   if allowed {
                       self.loadRecordingUI()
                   } else {
                       // failed to record!
                   }
               }
           }
        } catch {
           // failed to record!
               }
        
        }
        
        func loadRecordingUI() {
            recordButton = UIButton(frame: CGRect(x: view.center.x - 40.5, y: view.bounds.maxY - 150, width: 81, height: 86))
            recordButton.setImage(notRecording, for: .normal)
            recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
            view.addSubview(recordButton)
            
            self.view = view
            
        }
        
        func startRecording() {
            self.audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
            try! recordingSession.setCategory(.playAndRecord, mode: .default)
            try! recordingSession.setActive(true)
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            do {
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                audioRecorder.delegate = self
                audioRecorder.record()

                recordButton.setImage(Recording, for: .normal)
            } catch {
                finishRecording(success: false)
            }
        }

        func finishRecording(success: Bool) {
            audioRecorder.stop()
            audioRecorder = nil

            if success {
                recordButton.setImage(notRecording, for: .normal)
                let url = self.audioFilename
                self.transcribeAudio(url: url!)
            } else {
                recordButton.setImage(notRecording, for: .normal)
                // recording failed :(
            }
        }
        
        @objc func recordTapped() {
            if audioRecorder == nil {
                startRecording()
            } else {
                finishRecording(success: true)
            }
        }
        
        func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
            if !flag {
                finishRecording(success: false)
            }
        }
        
        func getDocumentsDirectory() -> URL {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return paths[0]
        }
        
        func requestTranscribePermissions() {
            SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
                DispatchQueue.main.async {
                    if authStatus == .authorized {
                        print("Good to go!")
                        //let url = Bundle.main.url(forResource: "test", withExtension: "m4a")!
                    } else {
                        print("Transcription permission was declined.")
                    }
                }
            }
        }
        func transcribeAudio(url: URL) {
            // create a new recognizer and point it at our audio
            let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "pt-BR"))
            let request = SFSpeechURLRecognitionRequest(url: url)

            // start recognition!
            recognizer?.recognitionTask(with: request) { [unowned self] (result, error) in
                // abort if we didn't get any transcription back
                guard let result = result else {
                    print("There was an error: \(error!)")
                    return
                }

                // if we got the final transcription back, print it
                if result.isFinal {
                    // pull out the best transcription...
                    print(result.bestTranscription.formattedString)
                    self.semaphore = DispatchSemaphore (value: 0)
                    self.sendMessage(message: result.bestTranscription.formattedString, semaphore: self.semaphore)
                    self.semaphore.wait()
                    self.textToSpeech(text: self.watsonResponse!)
                }
            }
        }
        func textToSpeech(text:String){
            try! recordingSession.setCategory(AVAudioSession.Category.ambient)
            let utterance = AVSpeechUtterance(string: text)
            var voiceToUse: AVSpeechSynthesisVoice?
            for voice in AVSpeechSynthesisVoice.speechVoices() {
            //print(voice)
                if #available(iOS 13.7, *) {
                    if voice.name == "Luciana" {
                    voiceToUse = voice
                    }
                }
            }
            print(text)
            utterance.voice = voiceToUse
            utterance.volume = 1
            let synth = AVSpeechSynthesizer()
            synth.speak(utterance)
        }
        
        func openSession(semaphore:DispatchSemaphore){
            //semaphore = DispatchSemaphore (value: 0)

            var request = URLRequest(url: URL(string: "https://api.us-south.assistant.watson.cloud.ibm.com/instances/22b11935-9f61-4093-96a9-fdd9a574bc89/v2/assistants/33ef99d5-2bfa-441c-be67-10b974f335ac/sessions?version=2020-04-01&content-Type=application/json")!,timeoutInterval: Double.infinity)
            request.addValue("Basic YXBpa2V5OmNlcjlSNXQwOWhBR3EtNE94QkVHTTJuS0pIM05jbHd5dFV6MmJVUkVKcGpt", forHTTPHeaderField: "Authorization")

            request.httpMethod = "POST"

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                do {
                    let decoder = JSONDecoder()
                    let sessioncode = try decoder.decode(SessionId.self, from: data!)
                    self.session_id = sessioncode.sessionID
                    //print(self.session_id ?? "error1")
                } catch {
                    print("Erro : " + error.localizedDescription)
                }
                
              semaphore.signal()
            }

            task.resume()
        }
        
        func sendMessage(message : String, semaphore:DispatchSemaphore) {

            let parameters = "{\"input\": {\"text\": \""+message+"\"}}"
            let postData = parameters.data(using: .utf8)
            let session = self.session_id ?? "error"

            var request = URLRequest(url: URL(string: "https://api.us-south.assistant.watson.cloud.ibm.com/instances/22b11935-9f61-4093-96a9-fdd9a574bc89/v2/assistants/33ef99d5-2bfa-441c-be67-10b974f335ac/sessions/"+session+"/message?version=2020-04-01")!,timeoutInterval: Double.infinity)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Basic YXBpa2V5OmNlcjlSNXQwOWhBR3EtNE94QkVHTTJuS0pIM05jbHd5dFV6MmJVUkVKcGpt", forHTTPHeaderField: "Authorization")

            request.httpMethod = "POST"
            request.httpBody = postData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                do {
                    let decoder = JSONDecoder()
                    let message = try decoder.decode(WatsonMessage.self, from: data!)
                    self.watsonResponse = message.output.generic[0].text
                    semaphore.signal()
                    
                  } catch {
                      print("Erro : " + error.localizedDescription)
                  }
              
            }

            task.resume()
            
        }


    }

