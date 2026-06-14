#!/usr/bin/env python3
"""Rename files to fix compile order — types used by others get _ prefix."""
import os

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# Files that define types referenced by others — must compile first
TO_PREFIX = [
    'document.cj', 'range.cj', 'character.cj', 'tag.cj', 'parser.cj',
    'entities.cj', 'comment.cj', 'node.cj', 'element.cj', 'attributes.cj',
    'attribute.cj', 'shared_constants.cj', 'token.cj', 'html_tree_builder.cj',
    'xml_tree_builder.cj', 'tree_builder.cj', 'entities_data.cj',
    'parse_settings.cj', 'source_reader.cj', 'platform.cj',
    'k_cloneable.cj', 'validate.cj', 'string_util.cj', 'normalizer.cj',
    'leaf_node.cj', 'text_node.cj', 'data_node.cj', 'c_data_node.cj',
    'node_utils.cj', 'node_iterator.cj', 'node_traversor.cj',
    'node_filter.cj', 'node_visitor.cj', 'node_evaluator.cj',
    'structural_evaluator.cj', 'combining_evaluator.cj',
    'collector.cj', 'selector.cj', 'query_parser.cj',
    'safelist.cj', 'cleaner.cj', 'form_element.cj', 'pseudo_text_element.cj',
    'stream_parser.cj', 'quiet_appendable.cj', 'string_builder.cj',
    'printer.cj', 'unbaser.cj', 'meta_data.cj',
]

for f in TO_PREFIX:
    fpath = os.path.join(SRC, f)
    if os.path.exists(fpath) and not f.startswith('_'):
        new_fpath = os.path.join(SRC, '_' + f)
        os.rename(fpath, new_fpath)
        print(f"Renamed: {f} -> _{f}")

print(f"\nFiles with _ prefix: {len([f for f in os.listdir(SRC) if f.startswith('_')])}")
