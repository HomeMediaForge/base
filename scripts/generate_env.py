#!/usr/bin/env python3
"""
Generador interactivo de .env para HomeMediaForge.

Utiliza una interfaz ncurses sencilla para solicitar los valores más
importantes definidos en env.template y genera (o reemplaza) el archivo .env
en la raíz del proyecto.

Controles:
  ↑ / ↓   - Seleccionar variable
  Enter   - Editar el valor de la variable seleccionada
  s       - Guardar los cambios en .env
  q       - Salir sin guardar
"""

from __future__ import annotations

import curses
import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

RE_ASSIGN = re.compile(r"^([A-Z0-9_]+)=(.*)$")
RE_DEFAULT_IN_EXPANSION = re.compile(r"\$\{[^:}]+:-([^}]+)\}")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_PATH = PROJECT_ROOT / "env.template"
OUTPUT_PATH = PROJECT_ROOT / ".env"


@dataclass
class TemplateEntry:
    kind: str  # "assign" o "other"
    raw: str
    key: Optional[str] = None
    current_value: Optional[str] = None
    padding: str = ""
    comment: str = ""


@dataclass
class Field:
    key: str
    label: str
    initial_display: str
    value: str
    modified: bool = False


PROMPT_FIELDS = [
    ("PUID", "UID del usuario que ejecutará los contenedores"),
    ("PGID", "GID del grupo que ejecutará los contenedores"),
    ("TZ", "Zona horaria (formato IANA)"),
    ("HOSTNAME", "Hostname visible dentro de los contenedores"),
    ("EMAIL", "Correo para notificaciones/certificados"),
    ("DOMAINS", "Dominio principal para proxy/SSL"),
    ("STACK_ROOT", "Ruta raíz donde se guardan los datos"),
    ("HOMEMEDIAFORGE_NET_NAME", "Nombre de la red bridge principal"),
    ("HOMEMEDIAFORGE_NET_SUBNET", "Subred CIDR para IPs fijas"),
    ("PLEX_IPV4", "IP fija asignada a Plex"),
    ("JELLYFIN_IPV4", "IP fija asignada a Jellyfin (NVIDIA)"),
    ("JELLYSEERR_IPV4", "IP fija asignada a Jellyseerr"),
    ("QBITTORRENT_IPV4", "IP fija asignada a qBittorrent"),
    ("JELLYSEERR_PORT", "Puerto host para Jellyseerr"),
]


def parse_env_template(path: Path) -> List[TemplateEntry]:
    entries: List[TemplateEntry] = []
    if not path.exists():
        raise FileNotFoundError(f"No se encontró env.template en {path}")

    for raw_line in path.read_text().splitlines():
        match = RE_ASSIGN.match(raw_line)
        if not match:
            entries.append(TemplateEntry(kind="other", raw=raw_line))
            continue

        key, remainder = match.groups()
        comment = ""
        value_section = remainder

        if "#" in remainder:
            idx = remainder.index("#")
            comment = remainder[idx:]
            value_section = remainder[:idx]

        value_section = value_section.rstrip()
        padding = ""
        if value_section:
            stripped_value = value_section.rstrip()
            padding = value_section[len(stripped_value) :]
            value_section = stripped_value

        entries.append(
            TemplateEntry(
                kind="assign",
                raw=raw_line,
                key=key,
                current_value=value_section.strip(),
                padding=padding,
                comment=comment,
            )
        )

    return entries


def extract_display_value(value: str) -> str:
    if value is None:
        return ""
    match = RE_DEFAULT_IN_EXPANSION.fullmatch(value)
    if match:
        return match.group(1)
    # Si la expresión contiene expansión con valor por defecto, pero rodeada de texto
    match_partial = RE_DEFAULT_IN_EXPANSION.search(value)
    if match_partial:
        return match_partial.group(1)
    return value


def build_fields(entries: List[TemplateEntry]) -> List[Field]:
    entry_map: Dict[str, TemplateEntry] = {
        entry.key: entry for entry in entries if entry.kind == "assign"
    }
    fields: List[Field] = []

    for key, label in PROMPT_FIELDS:
        entry = entry_map.get(key)
        if entry is None or entry.current_value is None:
            continue
        display_value = extract_display_value(entry.current_value)
        fields.append(
            Field(
                key=key,
                label=label,
                initial_display=display_value,
                value=display_value,
            )
        )

    return fields


def write_env(entries: List[TemplateEntry]) -> None:
    lines: List[str] = []
    for entry in entries:
        if entry.kind != "assign":
            lines.append(entry.raw)
            continue

        value = entry.current_value or ""
        line = f"{entry.key}={value}"
        if entry.padding:
            line += entry.padding
        if entry.comment:
            line += entry.comment
        lines.append(line)

    OUTPUT_PATH.write_text("\n".join(lines) + "\n")


def draw_screen(stdscr, fields: List[Field], selected_idx: int, message: str = "") -> None:
    stdscr.clear()
    height, width = stdscr.getmaxyx()

    title = "HomeMediaForge – Generador de .env"
    instructions = "↑↓ Seleccionar  •  Enter Editar  •  s Guardar  •  q Salir"

    stdscr.addstr(0, max(0, (width - len(title)) // 2), title, curses.A_BOLD)
    stdscr.addstr(2, max(0, (width - len(instructions)) // 2), instructions)

    col_key = 2
    col_value = 32

    for idx, field in enumerate(fields):
        attr = curses.A_REVERSE if idx == selected_idx else curses.A_NORMAL
        indicator = "»" if idx == selected_idx else " "
        label = f"{indicator} {field.key:<25} {field.value}"
        stdscr.addstr(4 + idx, col_key, label[: width - col_key - 1], attr)
        stdscr.addstr(
            4 + idx,
            col_value + 28,
            f"{field.label}"[: max(0, width - (col_value + 28) - 2)],
            attr,
        )

    if message:
        stdscr.addstr(height - 2, 2, message[: width - 4], curses.A_DIM)

    stdscr.refresh()


def prompt_input(stdscr, field: Field) -> Optional[str]:
    curses.echo()
    curses.curs_set(1)

    height, width = stdscr.getmaxyx()
    prompt_win = curses.newwin(4, width - 4, height - 5, 2)
    prompt_win.border()
    prompt_win.addstr(1, 2, f"{field.key} – {field.label}")
    prompt_win.addstr(2, 2, "Nuevo valor (dejar vacío para conservar el actual): ")
    prompt_win.refresh()

    input_start_col = len("Nuevo valor (dejar vacío para conservar el actual): ") + 2
    prompt_win.move(2, input_start_col)

    try:
        user_input = prompt_win.getstr().decode("utf-8")
    except KeyboardInterrupt:
        user_input = ""

    curses.noecho()
    curses.curs_set(0)
    return user_input.strip()


def update_entries_with_fields(entries: List[TemplateEntry], fields: List[Field]) -> None:
    entry_map: Dict[str, TemplateEntry] = {
        entry.key: entry for entry in entries if entry.kind == "assign"
    }
    for field in fields:
        if not field.modified:
            continue
        entry = entry_map.get(field.key)
        if entry is None:
            continue
        entry.current_value = field.value


def curses_main(stdscr) -> None:
    curses.curs_set(0)
    stdscr.nodelay(False)
    stdscr.keypad(True)

    entries = parse_env_template(TEMPLATE_PATH)
    fields = build_fields(entries)

    if not fields:
        raise RuntimeError("No se encontraron variables configurables para mostrar.")

    selected_idx = 0
    message = ""

    while True:
        draw_screen(stdscr, fields, selected_idx, message)
        message = ""
        key = stdscr.getch()

        if key in (curses.KEY_UP, ord("k")):
            selected_idx = (selected_idx - 1) % len(fields)
        elif key in (curses.KEY_DOWN, ord("j")):
            selected_idx = (selected_idx + 1) % len(fields)
        elif key in (curses.KEY_ENTER, 10, 13):
            field = fields[selected_idx]
            user_value = prompt_input(stdscr, field)
            if user_value:
                field.value = user_value
                field.modified = True
            else:
                message = "Sin cambios."
        elif key in (ord("s"), ord("S")):
            update_entries_with_fields(entries, fields)
            write_env(entries)
            message = f".env actualizado en {OUTPUT_PATH}"
        elif key in (ord("q"), ord("Q")):
            break


def main() -> None:
    if not TEMPLATE_PATH.exists():
        raise SystemExit(f"No se encontró env.template en {TEMPLATE_PATH}")

    try:
        curses.wrapper(curses_main)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
