"""
Module for preparing inverted indexes based on uploaded documents
"""

import sys
import json
import re
from argparse import ArgumentParser, ArgumentTypeError, FileType
from io import TextIOWrapper
from typing import Dict, List, Iterable

DEFAULT_PATH_TO_STORE_INVERTED_INDEX = "inverted.index"

STOP_WORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
    "has", "he", "in", "is", "it", "its", "of", "on", "or", "that",
    "the", "to", "was", "were", "will", "with", "this", "which", "but",
    "not", "have", "had", "his", "her", "their", "they", "them", "you",
    "your", "i", "we", "our", "us"
}


class EncodedFileType(FileType):
    """File encoder"""

    def __call__(self, string):
        # the special argument "-" means sys.std{in,out}
        if string == "-":
            if "r" in self._mode:
                stdin = TextIOWrapper(sys.stdin.buffer, encoding=self._encoding)
                return stdin
            if "w" in self._mode:
                stdout = TextIOWrapper(sys.stdout.buffer, encoding=self._encoding)
                return stdout
            msg = 'argument "-" with mode %r' % self._mode
            raise ValueError(msg)

        # all other arguments are used as file names
        try:
            return open(string, self._mode, self._bufsize, self._encoding, self._errors)
        except OSError as exception:
            args = {"filename": string, "error": exception}
            message = "can't open '%(filename)s': %(error)s"
            raise ArgumentTypeError(message % args)

    def print_encoder(self):
        """printer of encoder"""
        print(self._encoding)


class InvertedIndex:
    """
    This module is necessary to extract inverted indexes from documents.
    """

    def __init__(self, words_ids: Dict[str, List[int]]):
        self.words_ids = words_ids

    def query(self, words: List[str]) -> List[int]:
        """Return document ids containing all query words."""
        words = [word.lower() for word in words if word and word.lower() not in STOP_WORDS]

        if not words:
            return []

        result = set(self.words_ids.get(words[0], []))

        for word in words[1:]:
            result &= set(self.words_ids.get(word, []))

        return sorted(result)

    def dump(self, filepath: str) -> None:
        """Save inverted index to a JSON file."""
        with open(filepath, "w", encoding="utf-8") as file_object:
            json.dump(self.words_ids, file_object)

    @classmethod
    def load(cls, filepath: str):
        """Load inverted index from a JSON file."""
        with open(filepath, "r", encoding="utf-8") as file_object:
            words_ids = json.load(file_object)

        return cls(words_ids)


def load_documents(filepath: str) -> Dict[int, str]:
    """Read documents from file. Each row: doc_id<TAB>content."""
    documents = {}

    with open(filepath, "r", encoding="utf-8") as file_object:
        for line in file_object:
            line = line.strip()

            if not line:
                continue

            doc_id, content = line.lower().split("\t", 1)
            documents[int(doc_id)] = content

    return documents


def build_inverted_index(documents):
    words_ids = {}

    for doc_id, text in documents.items():
        words = re.split(r"\W+", text.lower())

        for word in words:
            if word and word not in STOP_WORDS:
                if word not in words_ids:
                    words_ids[word] = set()

                words_ids[word].add(doc_id)

    words_ids = {
        word: sorted(doc_ids)
        for word, doc_ids in words_ids.items()
    }

    return InvertedIndex(words_ids)


def callback_build(arguments) -> None:
    """process build runner"""
    return process_build(arguments.dataset, arguments.output)


def process_build(dataset, output) -> None:
    """
    Function is responsible for running of a pipeline to load documents,
    build and save inverted index.
    :param arguments: key/value pairs of arguments from 'build' subparser
    :return: None
    """
    documents: Dict[int, str] = load_documents(dataset)
    inverted_index = build_inverted_index(documents)
    inverted_index.dump(output)


def callback_query(arguments) -> None:
    """ "callback query runner"""
    process_query(arguments.query, arguments.index)


def process_query(queries, index) -> None:
    """Load inverted index and print matching document ids for each query."""
    inverted_index = InvertedIndex.load(index)

    for query in queries:
        if isinstance(query, str):
            raw_query = query
        else:
            raw_query = " ".join(query)

        words = [word for word in re.split(r"\W+", raw_query.lower()) if word]

        doc_indexes = ",".join(str(value) for value in inverted_index.query(words))
        print(doc_indexes)


def setup_subparsers(parser) -> None:
    """
    Initial subparsers with arguments.
    :param parser: Instance of ArgumentParser
    """
    subparser = parser.add_subparsers(dest="command")
    build_parser = subparser.add_parser(
        "build",
        help="this parser is need to load, build"
        " and save inverted index bases on documents",
    )
    build_parser.add_argument(
        "-d",
        "--dataset",
        required=True,
        help="You should specify path to file with documents. ",
    )
    build_parser.add_argument(
        "-o",
        "--output",
        default=DEFAULT_PATH_TO_STORE_INVERTED_INDEX,
        help="You should specify path to save inverted index. "
        "The default: %(default)s",
    )
    build_parser.set_defaults(callback=callback_build)

    query_parser = subparser.add_parser(
        "query", help="This parser is need to load and apply inverted index"
    )
    query_parser.add_argument(
        "--index",
        default=DEFAULT_PATH_TO_STORE_INVERTED_INDEX,
        help="specify the path where inverted indexes are. " "The default: %(default)s",
    )
    query_file_group = query_parser.add_mutually_exclusive_group(required=True)
    query_file_group.add_argument(
        "-q",
        "--query",
        dest="query",
        action="append",
        nargs="+",
        help="you can specify a sequence of queries to process them overall",
    )
    query_file_group.add_argument(
        "--query_from_file",
        dest="query",
        type=EncodedFileType("r", encoding="utf-8"),
        # default=TextIOWrapper(sys.stdin.buffer, encoding='utf-8'),
        help="query file to get queries for inverted index",
    )
    query_parser.set_defaults(callback=callback_query)


def main():
    """
    Starter of the pipeline
    """
    parser = ArgumentParser(
        description="Inverted Index CLI is need to load, build,"
        "process query inverted index"
    )
    setup_subparsers(parser)
    arguments = parser.parse_args()
    arguments.callback(arguments)


if __name__ == "__main__":
    main()
