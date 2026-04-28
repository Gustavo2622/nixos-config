# Local LLM backend — ROCm on AMD GPU, accessible over Tailscale
{pkgs, ...}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    host = "0.0.0.0";
    port = 11434;
  };

  networking.firewall.allowedTCPPorts = [11434];
}
