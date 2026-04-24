# OBS Studio with plugins: wlrobs, pipewire-audio-capture, vkcapture, source-clone,
# move-transition, composite-blur, and backgroundremoval.
{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;
    #enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-vkcapture
      obs-source-clone
      obs-move-transition
      obs-composite-blur
      obs-backgroundremoval
    ];
  };
}
