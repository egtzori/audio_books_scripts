#!/usr/bin/env python3
"""Find audiobook cover art online.

Usage: cover_lookup.py TITLE [AUTHOR] [SIZE]

Tries the Apple iTunes Search API (audiobooks, square art), then Open Library
(print covers). Prints one line "<url>\t<description>\t<title>\t<author>" for
the first result whose title and author match, or nothing. Network errors go to stderr and never
fail the caller. Stdlib only.
"""

import json
import re
import sys
import urllib.parse
import urllib.request

TIMEOUT_SECONDS = 15
DEFAULT_SIZE = "1400x1400"
USER_AGENT = "audio_books_scripts/1.0 (m4b cover lookup)"

# Results like "Summary of X", "Study Guide: X" are companion books, not X.
COMPANION_RE = re.compile(r"^\s*(summary|study guide|workbook|analysis|key takeaways)\b", re.I)


def words(text):
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).split()


def core_title(title):
    """'Fat Chance: Beating ... (Unabridged)' -> 'Fat Chance'."""
    title = re.sub(r"[(\[].*?[)\]]", " ", title)
    return title.split(":")[0]


def title_matches(query, candidate):
    """Match when one core title's words are all contained in the other's words.

    Lenient on purpose: the query may be a folder name with the author in it
    ('The Hacking of the American Mind - R.H. Lustig').
    """
    if COMPANION_RE.match(candidate):
        return False
    q, c = set(words(core_title(query))), set(words(core_title(candidate)))
    return bool(q and c) and (q <= c or c <= set(words(query)))


def author_matches(author, candidate):
    if not author:
        return True
    names = words(author)
    return bool(names) and names[-1] in words(candidate)


def fetch_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return json.load(response)


def from_itunes(title, author, size):
    term = f"{core_title(title)} {author}".strip()
    query = urllib.parse.urlencode({"term": term, "media": "audiobook", "limit": 10})
    data = fetch_json(f"https://itunes.apple.com/search?{query}")
    for result in data.get("results", []):
        name = result.get("collectionName", "")
        artist = result.get("artistName", "")
        art = result.get("artworkUrl100", "")
        if art and title_matches(title, name) and author_matches(author, artist):
            # Artwork URLs end in "/100x100bb.jpg"; the size segment can be raised.
            big = re.sub(r"/\d+x\d+bb\.(jpg|png)$", f"/{size}bb.jpg", art)
            return big, f"iTunes: {name} by {artist}", name, artist
    return None


def from_openlibrary(title, author, _size):
    params = {"title": core_title(title), "limit": 10, "fields": "title,author_name,cover_i"}
    if author:
        params["author"] = author
    data = fetch_json(f"https://openlibrary.org/search.json?{urllib.parse.urlencode(params)}")
    for doc in data.get("docs", []):
        name = doc.get("title", "")
        authors = ", ".join(doc.get("author_name") or [])
        cover_id = doc.get("cover_i")
        if cover_id and title_matches(title, name) and author_matches(author, authors):
            return (
                f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg?default=false",
                f"Open Library: {name} by {authors}",
                name,
                authors,
            )
    return None


def main(argv):
    if len(argv) < 2 or not argv[1].strip():
        print("usage: cover_lookup.py TITLE [AUTHOR] [SIZE]", file=sys.stderr)
        return 2
    title = argv[1].strip()
    author = argv[2].strip() if len(argv) > 2 else ""
    size = argv[3] if len(argv) > 3 and re.fullmatch(r"\d+x\d+", argv[3]) else DEFAULT_SIZE

    for finder in (from_itunes, from_openlibrary):
        try:
            found = finder(title, author, size)
        except Exception as error:  # network/JSON errors: try the next source
            print(f"cover lookup ({finder.__name__}): {error}", file=sys.stderr)
            continue
        if found:
            print("\t".join(field.replace("\t", " ") for field in found))
            return 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
