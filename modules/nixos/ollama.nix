# Local LLM backend — ROCm on AMD GPU, accessible over Tailscale
{pkgs, ...}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    host = "0.0.0.0";
    port = 11434;
    # Pre-pull models we depend on at activation. Other chat/coding models live
    # outside this list (manually pulled) since they're discretionary.
    loadModels = [
      # 1024-dim multilingual embeddings, 8192-token context. Long context
      # matters for full crypto abstracts (mxbai-embed-large's 512 was too
      # tight). Same dim as the previous mxbai-embed-large → no schema change.
      "bge-m3"
    ];
  };

  networking.firewall.allowedTCPPorts = [11434];
}
