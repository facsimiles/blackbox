/* ProcessWatcher.vala
 *
 * Copyright 2023 Paulo Queiroz <pvaqueiroz@gmail.com>
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

public class Terminal.Process : Object {
  /**
   * This signal is emitted when the foreground task of a shell finishes.
   */
  public signal void foreground_task_finished ();

  /**
   * This is the file descriptor used by the terminal we're tracking. This must
   * be set during instanciation of this class and may not be modified later.
   */
  public int terminal_fd { get; construct set; }

  /**
   * This is the controlling PID for a terminal session. It will point to the
   * user's shell, in most cases. If the terminal was created with a different
   * command (i.e., `blackbox --command "sleep 300"`), this will point to the
   * spawned process instead.
   */
  public Pid pid { get; set; default = -1; }

  /**
   * This is the PID of the process currently running at the top of the user's
   * shell (e.g., if the user opened a terminal with bash, then opened Neovim
   * with `nvim`, the foreground task for this session, and, consequently, this
   * PID, will point to Neovim).
   */
  public Pid foreground_pid { get; set; default = -1; }

  public string? last_foreground_task_command { get; set; default = null; }

  // TODO: we might want to keep track of background PIDs as well (if that's
  // even possible). That will allow us to alert the user of potential
  // background tasks thatProcessWatcher would be lost upon closing the tab.

  /***/
  public bool ended { get; set; default = false; }
}

namespace Terminal {
  const uint PROCESS_WATCHER_INTERVAL_MS = 500;
}

public class Terminal.ProcessWatcher : Object {

  private static ProcessWatcher? instance = null;
  private Gee.ArrayList<Process> process_list;
  private Gee.ArrayList<Process> pending_process_list;
  private bool watching = false;
  private Thread<void>? loop_thread = null;
  private Mutex mutex = Mutex ();

  private ProcessWatcher () {
    this.process_list = new Gee.ArrayList<Process> ();
    this.pending_process_list = new Gee.ArrayList<Process> ();
  }

  public static ProcessWatcher get_instance () {
    if (instance == null) {
      instance = new ProcessWatcher ();
    }
    return instance;
  }

  public bool watch (Process process) {
    lock (this.pending_process_list) {
      this.pending_process_list.add (process);
    }

    if (!this.watching) {
      this.start_watching ();
    }

    return true;
  }

  private void start_watching () {
    this.watching = true;
    this.loop_thread = new Thread<void> ("process-watcher", this.t_watch_loop);
    //  Timeout.add (PROCESS_WATCHER_INTERVAL_MS, this.watch_loop);
  }

  private void stop_watching () {
    this.mutex.@lock ();
    this.loop_thread.join ();
    this.watching = false;
    this.loop_thread = null;
    this.mutex.@unlock ();
  }

  private bool watch_loop () {
    this.mutex.@lock ();

    foreach (var process in this.process_list) {
      this.check_process (process);
      // FIXME: it is usually a bad idea to remove items from an array while
      // iterating over it. A filter function is probably the best move here.
      if (process.ended) {
        this.process_list.remove (process);
      }
    }

    bool ret = this.process_list.size > 0;
    this.watching = ret;
    this.mutex.@unlock ();
    // If this function returns `false` it will no longer be called in an
    // interval
    return ret;
  }

  // This is the watch function that runs in an infinite loop and checks for
  // process updates periodically. This function should be executed in a
  // separate thread.
  private void t_watch_loop () {
    // TODO: exit loop when there are no more processes on the list. This will
    // happen if:
    //
    // - We support having Black Box's main window open without any tabs
    // - The last tab in a window is closed but a preferences window remais
    //   open (in which case the app doesn't close)
    while (true) {
      this.mutex.@lock ();

      lock (this.pending_process_list) {
        if (this.pending_process_list.size > 0) {
          foreach (var process in this.pending_process_list) {
            if (!this.process_list.contains (process)) {
              this.process_list.add (process);
            }
          }
          this.pending_process_list.clear ();
        }
      }

      message ("Watching %d processes", this.process_list.size);

      foreach (var process in this.process_list) {
        this.check_process (process);
      }

      for (int i = 0; i < this.process_list.size;) {
        if (this.process_list.get (i).ended) {
          this.process_list.remove_at (i);
        }
        else {
          i++;
        }
      }

      bool ret = this.process_list.size > 0;
      this.watching = ret;
      this.mutex.@unlock ();

      if (!ret) {
        break;
      }

      Thread.usleep (1000 * PROCESS_WATCHER_INTERVAL_MS);
    }
  }

  private bool is_process_still_running (Pid pid) {
    try {
      int status;
      host_or_flatpak_spawn ({ "ps", "-p", pid.to_string () }, out status);

      return status == 0;
    }
    catch (Error e) {
      warning ("%s", e.message);
    }
    return false;
  }

  private void check_process (Process process) {
    try {
      // TODO: check if we previously had a foreground process running. If so,
      // check that it still is and fire and event if not.
      {
        if (
          process.foreground_pid >= 0 &&
          !is_process_still_running (process.foreground_pid)
        ) {
          process.foreground_task_finished ();
          process.foreground_pid = -1;
          message ("Foreground task finished '%s'", process.last_foreground_task_command);
        }
      }

      // TODO: check if there is a current running foreground process.

      {
        get_foreground_process.begin (process.terminal_fd, null, (_, res) => {
          int foreground_pid = get_foreground_process.end (res);

          if (
            foreground_pid >= 0 &&
            foreground_pid != process.pid &&
            foreground_pid != process.foreground_pid
          ) {
            process.foreground_pid = foreground_pid;
            process.last_foreground_task_command = get_process_cmdline (foreground_pid);

            message ("New foreground task found '%s'", process.last_foreground_task_command);
          }
        });
      }

      // TODO: check that the main pid is still running
      {
        int status;
        host_or_flatpak_spawn ({ "ps", "-p", process.pid.to_string () },
                               out status);

        process.ended = status != 0;

        // do we need to emit an event for process finished?
      }

      //  message ("Checked %d. %s", process.pid, process.ended ? "Process ended" : "Process running.");
    }
    catch (GLib.Error e) {
      warning ("%s", e.message);
    }
  }
}
