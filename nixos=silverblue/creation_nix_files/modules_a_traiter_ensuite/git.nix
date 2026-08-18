{ config, pkgs, vars, ... }:

{
  programs.git = {
    enable = true;
    config = {
      init = {
        defaultBranch = "main";
      };
      credential = {
        helper = "store";
      };
      user = {
        name = vars.gitUsername;
        email = vars.gitUsermail;
      };
    };
  };
}
