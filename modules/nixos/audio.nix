# PipeWire audio stack: ALSA (with 32-bit), PulseAudio compat, Wireplumber session
# manager, and JACK with low-latency 256-quantum at 48kHz.
_: {
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # Session/Policy manager
    wireplumber.enable = true;

    # JACK settings
    jack.enable = true;
    
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 256;
      };
    };

    extraConfig.pipewire-pulse."92-low-latency" = {
      context.modules = [
        {
          name = "libpipewire-module-protocol-pulse";
          args.pulse = {
            min.req = "256/48000";
            default.req = "256/48000";
            max.req = "256/48000";
            min.quantum = "256/48000";
            max.quantum = "256/48000";
          };
        }
      ];
    };
  };
}
