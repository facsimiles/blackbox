/* Application.vala
 *
 * Copyright 2022 Paulo Queiroz <pvaqueiroz@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Terminal.Application : Adw.Application {
  private ActionEntry[] ACTIONS = {
    { "focus-next-tab", on_focus_next_tab },
    { "focus-previous-tab", on_focus_previous_tab },
    { "new-window", on_new_window },
    { "about", on_about },
    //  { "quit", on_app_quit },
  };

  public Application () {
    Object (
      application_id: "com.raggesilver.BlackBox",
      flags: ApplicationFlags.HANDLES_COMMAND_LINE
    );

    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.textdomain (GETTEXT_PACKAGE);
    Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

    this.add_action_entries (ACTIONS, this);
    this.add_main_option_entries (CommandLine.option_entries());

    var keymap = Keymap.get_default ();
    keymap.apply (this);
  }

  public override void activate () {
    // Avoid opening a new window if one is already open
    foreach (var window in this.get_windows ()) {
      if (window is Window) {
        // This seems the right way to go about "reclaiming" focus for a window.
        // However, it doesn't work on Xorg nor on Wayland - it does nothing.
        window.present ();
        return;
      }
    }

    new Window (this).show ();
  }

  // Command line handlers

  protected override bool local_command_line (ref weak string[] arguments, out int exit_status) {
    CommandLine.check_dash_dash_opt (arguments);
    return base.local_command_line (ref arguments, out exit_status);
  }

  public override int handle_local_options(GLib.VariantDict options) {
    int? exit_status = CommandLine.handle_local_options (options);
    if (exit_status != null) {
      return exit_status;
    }
    return base.handle_local_options (options);
  }

  public override int command_line (GLib.ApplicationCommandLine cmd) {
    CommandLineOptions options;
    CommandLine.parse_command_line (cmd, out options);

    this.hold ();
    if (options.command_cnt > 0) {
      for (int i = 0; i < options.command_cnt; i++) {
        new Window(this, options.command?[i], options.current_working_dir?[i]).show ();
      }
    } else {
      this.activate ();
    }
    this.release ();
    return 0;
  }

  //  private void on_app_quit () {
  //    // This involves confirming before closing tabs/windows
  //    warning ("App quit is not implemented yet.");
  //  }

  private void on_about () {
    var win = create_about_dialog () as Gtk.Window;
    win.set_transient_for (this.get_active_window ());
    win.show ();
  }

  private void on_new_window () {
    // TODO: this method has an issue: if the current active window is not a
    // main window, the check will fail and the new window will not persist the
    // CWD. An alternative solution would be to keep track of the last active
    // main window.
    var w = this.get_active_window ();
    Terminal? active_terminal = (w is Window) ? w.active_terminal : null;

    string? cwd = Terminal
      .get_current_working_directory_for_new_session (active_terminal);

    new Window (this, null, cwd, false).show ();
  }

  private void on_focus_next_tab () {
    (this.get_active_window () as Window)?.focus_next_tab ();
  }

  private void on_focus_previous_tab () {
    (this.get_active_window () as Window)?.focus_previous_tab ();
  }
}
