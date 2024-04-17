//
//  ContentViewModel.swift
//  Sleep Sound
//
//  Created by Max Buchholz on 4/13/24.
//

import Foundation
import AVFoundation
import Accelerate
protocol AudioDelegate: AnyObject {
    func audio(didStart manager: Audio)
    func audio(didStop manager: Audio)
    func audio(didPause manager: Audio)
}
class Audio {
    weak var delegate: AudioDelegate?
    
    // Variables
    private let player = AVAudioPlayerNode()
    private let audioEngine = AVAudioEngine()
    private var audioFileBuffer: AVAudioPCMBuffer?
    private var EQNode: AVAudioUnitEQ?
    public var waveMag : [Float] = []
    public var fftMag : [Float] = []
    init?(music: String, frequencies: [Int]) {
        setUpEngine(with: music, frequencies: frequencies)
    }
    
    fileprivate func setUpEngine(with name: String, frequencies: [Int]) {
        // Load a music file
        do {
            guard let musicUrl = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
            let audioFile = try AVAudioFile(forReading: musicUrl)
            audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: UInt32(audioFile.length))
            try audioFile.read(into: audioFileBuffer!)
        } catch {
            assertionFailure("failed to load the music. Error: \(error)")
            return
        }
        do{
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(AVAudioSession.Category.soloAmbient)
            do { try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: .mixWithOthers);
            try AVAudioSession.sharedInstance().setActive(true) } catch { print(error) }
        } catch{
            
        }
        // initial Equalizer.
        EQNode = AVAudioUnitEQ(numberOfBands: frequencies.count)
        EQNode!.globalGain = 1
        for i in 0...(EQNode!.bands.count-1) {
            EQNode!.bands[i].frequency  = Float(frequencies[i])
            EQNode!.bands[i].gain       = 0
            EQNode!.bands[i].bypass     = false
            EQNode!.bands[i].filterType = .parametric
        }
        
        // Attach nodes to an engine.
        audioEngine.attach(EQNode!)
        audioEngine.attach(player)
        
        // Connect player to the EQNode.
        let mixer = audioEngine.mainMixerNode
        audioEngine.connect(player, to: EQNode!, format: mixer.outputFormat(forBus: 0))
        
        // Connect the EQNode to the mixer.
        audioEngine.connect(EQNode!, to: mixer, format: mixer.outputFormat(forBus: 0))
        
        // Schedule player to play the buffer on a loop.
        if let audioFileBuffer = audioFileBuffer {
            player.scheduleBuffer(audioFileBuffer, at: nil, options: .loops, completionHandler: nil)
        }
        let bufferSize = 512
        let waveDisplaySize = 100
        
        let fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(bufferSize),
            vDSP_DFT_Direction.FORWARD
        )
        
        audioEngine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: UInt32(bufferSize),
            format: nil){ [self] buffer, _ in
                //let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count:arraySize))
                let samples = buffer.floatChannelData?[0]
                if(waveMag.count != waveDisplaySize){
                    waveMag = Array(repeating: Float(0.0), count: waveDisplaySize)
                }
                var tempFullWave = Array(repeating: Float(0.0), count: bufferSize)
                    for i in 0..<(bufferSize){
                        if(i < waveDisplaySize){
                            waveMag[i] = (samples?[i])!
                        }
                        tempFullWave[i] = (samples?[i])!
                    fftMag = FFT.vfft(data: samples!, setup: fftSetup!)
                }
            }
        engineStart()
    }
    public func isEngineRunning() -> Bool {
        return audioEngine.isRunning
    }
    
    public func engineStart() {
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            assertionFailure("failed to audioEngine start. Error: \(error)")
        }
    }
    
    public func play() {
        player.play()
        delegate?.audio(didStart: self)
    }
    
    public func stop() {
        player.stop()
        delegate?.audio(didStop: self)
    }
    
    public func end(){
        audioEngine.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            assertionFailure("failed to audioEngine stop. Error: \(error)")
        }
    }
    
    public func pause() {
        player.pause()
        delegate?.audio(didStart: self)
    }
    public func setEquailizerOptions(gains: [Float]) async {
        guard let EQNode = EQNode else {
            return
        }
        for i in 0...(EQNode.bands.count-1) {
            EQNode.bands[i].gain = gains[i]
        }
    }
    public func setGain(gain : Float){
        guard let EQNode = EQNode else {
            return
        }
        EQNode.globalGain = gain
    }
}
