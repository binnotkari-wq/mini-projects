##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{
  programs.firefox = {
    languagePacks = [ "fr" ];
    preferences = {
      "browser.translations.automaticallyPopup" = false;
      "browser.startup.homepage" = "https://duckduckgo.com/";
      "intl.locale.requested" = "fr";
      "intl.accept_languages" = "fr-fr,fr";
      "spellchecker.dictionary" = "fr-FR";
      "spellchecker.dictionary_path" = "${pkgs.hunspellDicts.fr-any}/share/hunspell";
      "layout.spellcheckDefault" = 2;
    };  
    policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        Extensions = {
          Install = [
            "https://addons.mozilla.org/firefox/downloads/file/4822564/empiric_markdown_viewer-0.4.0.xpi"
            "https://addons.mozilla.org/firefox/downloads/file/4617846/kiwix_offline-4.3.0.xpi"
            "https://addons.mozilla.org/firefox/downloads/file/4591252/gnome_shell_integration-12.1.xpi"
            "https://addons.mozilla.org/firefox/downloads/file/4452159/claude_to_markdown-2025.3.11.xpi"
          ];
        };
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        DontCheckDefaultBrowser = true;  
        SearchEngines = {
          Remove = [
            "eBay"
            "Google"
            "Bing"
            "Ecosia"
            "Wikipedia"
            "Perplexity"
          ];
          Add = [
            {
                "Name" = "DuckDuckGo";
                "URLTemplate" = "https://duckduckgo.com/?q={searchTerms}&ia=web&assist=false";
                "IconURL" = "https://duckduckgo.com/favicon.ico";
                "Alias" = "ddg";
                "Description" = "Duckduckgo sans IA";
            }
          ];
          Default = "DuckDuckGo";
        };   
    };
  };
}
