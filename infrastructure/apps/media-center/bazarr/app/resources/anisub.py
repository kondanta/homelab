# -*- coding: utf-8 -*-
"""Bazarr/Subliminal provider for Anisub public subtitles."""

from __future__ import absolute_import

import logging

from guessit import guessit
from requests import Session
from subzero.language import Language
from subliminal.exceptions import ConfigurationError, ProviderError
from subliminal.video import Episode, Movie
from subliminal_patch.providers import Provider
from subliminal_patch.subtitle import Subtitle, guess_matches

logger = logging.getLogger(__name__)


class AnisubSubtitle(Subtitle):
    provider_name = "anisub"

    def __init__(self, language, item):
        super(AnisubSubtitle, self).__init__(language, page_link=item["urls"]["site"])
        self.item = item
        self.download_link = item["urls"].get("file") or item["urls"]["text"]
        self.release_info = item.get("release_name") or ""

    @property
    def id(self):
        return str(self.item["id"])

    def get_matches(self, video):
        media = self.item.get("media") or {}
        guessed = guessit(" ".join([
            media.get("title_romaji") or "",
            media.get("title_english") or "",
            self.release_info,
            self.item.get("content_type") or "",
        ]))
        self.matches |= guess_matches(video, guessed)
        if getattr(video, "imdb_id", None) and media.get("imdb_id") == video.imdb_id:
            self.matches.add("imdb_id")
        if isinstance(video, Episode):
            self.matches.update(["series"])
        if isinstance(video, Movie):
            self.matches.update(["title"])
        return self.matches


class AnisubProvider(Provider):
    subtitle_class = AnisubSubtitle
    languages = {Language("tur")}
    video_types = (Episode, Movie)

    def __init__(self, api_url="https://anisub.co/api/v1", api_key=None, search_limit=25):
        if not api_url:
            raise ConfigurationError("Anisub API URL is required")
        self.api_url = api_url.rstrip("/")
        self.api_key = api_key
        self.search_limit = int(search_limit or 25)
        self.session = None

    def initialize(self):
        self.session = Session()
        self.session.headers.update({"User-Agent": "Bazarr-Anisub/1.0"})
        if self.api_key:
            self.session.headers.update({"X-Anisub-Api-Key": self.api_key})

    def terminate(self):
        if self.session:
            self.session.close()

    def list_subtitles(self, video, languages):
        wanted = {Language("tur")}
        if languages and not (languages & wanted):
            return []

        params = {"limit": self.search_limit}
        if getattr(video, "imdb_id", None):
            params["imdb_id"] = video.imdb_id
        else:
            params["q"] = getattr(video, "series", None) or getattr(video, "title", None) or getattr(video, "name", "")

        if isinstance(video, Episode) and getattr(video, "episode", None):
            params["content_type"] = str(video.episode)

        logger.debug("Searching Anisub with params: %r", params)
        response = self.session.get(self.api_url + "/search", params=params, timeout=15)
        response.raise_for_status()
        payload = response.json()
        items = payload.get("data") or []
        subtitles = []
        for item in items:
            lang = Language.fromalpha3b(item.get("lang") or "tur")
            if lang in languages or not languages:
                subtitles.append(self.subtitle_class(lang, item))
        return subtitles

    def download_subtitle(self, subtitle):
        logger.info("Downloading Anisub subtitle %r", subtitle)
        response = self.session.get(subtitle.download_link, timeout=20)
        response.raise_for_status()
        content = response.content
        if not content:
            raise ProviderError("Empty subtitle returned by Anisub")
        subtitle.content = content
        return subtitle
