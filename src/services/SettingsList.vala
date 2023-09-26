/* SettingsList.vala
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

public class Terminal.SettingsList : Object {
  public GLib.SettingsBackend backend { get; private set; }
  public GLib.SettingsSchemaSource schema_source { get; private set; }

  public SettingsList (
    string schema_id,
    GLib.SettingsSchemaSource schema_source,
    bool recursive = true,
    GLib.SettingsBackend backend = SettingsBackend.get_default ()
  ) {
    Object (backend: backend);

    schema_source.lookup (schema_id, recursive);
  }
}
