// core/include/als/session.hpp — a modulokat összekötő központi objektum
//
//   Hangszer ──MIDI──► MidiTransport ──► Session::dispatch ─┬─► VirtualLayerEngine ──► MidiTransport ──► Hangszer
//                                                            └─► realtime listener (F8/FA/FC) ──► Smart Reader (Dart)
//   UI / CLI ──► Session::recall / styleStart / section / tempo ──► yamaha_proto ──► MidiTransport ──► Hangszer
//
#pragma once
#include "als/layer_engine.hpp"
#include "als/midi_transport.hpp"
#include "als/soft_registration.hpp"
#include "als/yamaha_proto.hpp"

#include <functional>
#include <memory>

namespace als {

class Session {
public:
  using RealtimeListener = std::function<void(uint8_t status, uint64_t tsUs)>;

  Session(std::unique_ptr<MidiTransport> transport, yamaha::ModelProfile profile)
      : transport_(std::move(transport)),
        profile_(std::move(profile)),
        layers_(*transport_, profile_.rightOneTxChannel) {
    transport_->setInputCallback([this](const uint8_t* m, size_t n, uint64_t ts) { dispatch(m, n, ts); });
  }

  // A hangszer és a felület eseményei
  void setRealtimeListener(RealtimeListener l) { realtime_ = std::move(l); }
  void dispatch(const uint8_t* m, size_t n, uint64_t ts) {
    if (n == 0) return;
    if (m[0] >= 0xF8) { if (realtime_) realtime_(m[0], ts); return; }   // Clock, Start, Stop
    if (m[0] == 0xF0) return;                                             // SysEx (pl. Identity Reply): később profil-felismerés
    layers_.onMidi(m, n, ts);
  }

  // Vezérlés a felületről
  void styleStart()                     { send(yamaha::styleStart()); }
  void styleStop()                      { send(yamaha::styleStop()); }
  void section(yamaha::Section s)       { if (profile_.supportsSectionSysex) send(yamaha::sectionSelect(s)); }
  void tempo(double bpm)                { send(yamaha::tempo(bpm)); }
  void identify()                       { send(yamaha::identityRequest()); }
  void recall(const SoftRegistration& r) { als::recall(r, profile_, *transport_); }

  VirtualLayerEngine& layers()                { return layers_; }
  const yamaha::ModelProfile& profile() const { return profile_; }
  MidiTransport& transport()                  { return *transport_; }

private:
  void send(const yamaha::Bytes& b) { transport_->sendBurst(b, 0); }

  std::unique_ptr<MidiTransport> transport_;
  yamaha::ModelProfile profile_;
  VirtualLayerEngine layers_;
  RealtimeListener realtime_;
};

} // namespace als
