#!/usr/bin/env python3
"""Sanity checks for Groundwork.xcodeproj/project.pbxproj without Xcode.

Parses the old-style (OpenStep) property list, then checks that every object
has an isa, every 24-character object id that is referenced exists, the
synced app folder and resource folders exist on disk, and the shared scheme
points at the app target. Xcode itself is the final word.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBX = ROOT / "Groundwork.xcodeproj" / "project.pbxproj"
SCHEME = ROOT / "Groundwork.xcodeproj" / "xcshareddata" / "xcschemes" / "Groundwork.xcscheme"


class Parser:
    def __init__(self, text):
        self.s = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
        self.s = re.sub(r"//[^\n]*", "", self.s)
        self.i = 0

    def ws(self):
        while self.i < len(self.s) and self.s[self.i] in " \t\r\n":
            self.i += 1

    def expect(self, ch):
        self.ws()
        if self.s[self.i:self.i + 1] != ch:
            raise SyntaxError(f"expected '{ch}' near: {self.s[self.i:self.i + 40]!r}")
        self.i += 1

    def value(self):
        self.ws()
        c = self.s[self.i]
        if c == "{":
            self.i += 1
            d = {}
            while True:
                self.ws()
                if self.s[self.i] == "}":
                    self.i += 1
                    return d
                key = self.value()
                self.expect("=")
                d[key] = self.value()
                self.expect(";")
        if c == "(":
            self.i += 1
            items = []
            while True:
                self.ws()
                if self.s[self.i] == ")":
                    self.i += 1
                    return items
                items.append(self.value())
                self.ws()
                if self.s[self.i] == ",":
                    self.i += 1
        if c == '"':
            self.i += 1
            out = []
            while self.s[self.i] != '"':
                if self.s[self.i] == "\\":
                    self.i += 1
                out.append(self.s[self.i])
                self.i += 1
            self.i += 1
            return "".join(out)
        m = re.compile(r"[A-Za-z0-9_$./\-:+]+").match(self.s, self.i)
        if not m:
            raise SyntaxError(f"unexpected text near: {self.s[self.i:self.i + 40]!r}")
        self.i = m.end()
        return m.group(0)


def main():
    problems = []
    text = PBX.read_text()
    try:
        plist = Parser(text).value()
    except (SyntaxError, IndexError) as error:
        print(f"project.pbxproj does not parse: {error}")
        return 1
    objects = plist.get("objects", {})
    ids = set(objects)
    if plist.get("rootObject") not in ids:
        problems.append("rootObject is missing")
    for oid, obj in objects.items():
        if not isinstance(obj, dict) or "isa" not in obj:
            problems.append(f"{oid} has no isa")
    for ref in set(re.findall(r"\b[0-9A-F]{24}\b", re.sub(r"/\*.*?\*/", "", text, flags=re.S))):
        if ref not in ids:
            problems.append(f"{ref} is referenced but not defined")

    for obj in objects.values():
        isa = obj.get("isa")
        if isa == "PBXFileSystemSynchronizedRootGroup":
            if not (ROOT / "App" / obj["path"]).is_dir():
                problems.append(f"synced folder App/{obj['path']} does not exist")
        if isa == "PBXFileReference" and obj.get("lastKnownFileType") == "folder":
            if not (ROOT / obj["path"]).is_dir():
                problems.append(f"resource folder {obj['path']} does not exist")
        if isa == "XCLocalSwiftPackageReference":
            if not (ROOT / obj["relativePath"] / "Package.swift").is_file():
                problems.append(f"local package {obj['relativePath']} has no Package.swift")

    targets = [k for k, o in objects.items() if o.get("isa") == "PBXNativeTarget"]
    scheme = SCHEME.read_text()
    for t in targets:
        if f'BlueprintIdentifier = "{t}"' not in scheme:
            problems.append("the shared scheme does not point at the app target")
    package = (ROOT / "GroundworkCore" / "Package.swift").read_text()
    for obj in objects.values():
        if obj.get("isa") == "XCSwiftPackageProductDependency" and f'name: "{obj["productName"]}"' not in package:
            problems.append(f"package has no product {obj['productName']}")

    if problems:
        print("Xcode project check failed:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"Xcode project check passed: {len(objects)} objects, {len(targets)} target, all references resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
