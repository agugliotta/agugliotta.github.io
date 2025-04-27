---
layout: post
title: "Add automcatic spell check into my Github Action Workflow"
date: 2025-04-27 10:57:57
tags: [github, workflow, actions, spellcheck]
---

The next step of the blog for me, was to integrate a spellcheck in the workflow of Github Actions.

I'm not a native English speaker and I want it to play a little with the workflows so this is what I end it with...

You'll need al least 3 files to accomplish this feature the way I did:

* A Workflow file inside the .github/workflows directory
* A YML file where all the login of the functionality will be
* A text file to ignore certain words


For the workflow we'll be using a Github action already created that it use PySpelling (a Python library), you can checkout the [link](https://github.com/rojopolis/spellcheck-github-actions).

I'm not expert in Github actions so I ended having some issues with the tag version of the repository. The solution I found was to use v0 which is means use the last version always.
In the end I wrote a file that it look like this:

{% highlight yaml %}
# .github/workflows/check_spelling.yml

name: Spellcheck
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  spelling:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    - name: Check Spelling
      uses: rojopolis/spellcheck-github-actions@v0
      with:
        config_path: .spellcheck.yml
        task_name: Markdown
{% endhighlight %}

In this file make a reference to the second file we need, the one with the logic:
```yaml
{% raw %}
matrix:
  - name: Markdown
    default_encoding: 'utf-8'
    expect_match: true
    sources:
      - '_posts/*.md'

    dictionary:
      wordlists:
        - '.wordlist.txt'

    aspell:
      lang: 'en'
      d: 'en_US'
      mode: 'markdown'
      ignore-case: true

    pipeline:
      - pyspelling.filters.context:
          context_visible_first: true
          escapes: '\\[\\`~]'
          delimiters:

            # ignore liquid nospell blocks
            #
            # example:
            #
            # {% comment %} begin nospell {% endcomment %}
            # [..]
            # {% comment %} end nospell {% endcomment %}
            #
            - open: '(?m)(\s{0,}?){%(\s+)?comment\2?%}\2?begin\2?nospell\2?{%\2?endcomment\2?%}'
              content: '[\S\s]+'
              close: '\1{%\2?comment\2?%}\2?end\2?nospell\2?{%\2?endcomment\2?%}'

            # ignore liquid highlight blocks
            #
            # example:
            #
            # {% highlight yaml %}
            # [..]
            # {% endhighlight %}
            #
            - open: '(?m)^(\s{0,}?){%(\s+)?highlight\2[A-z0-9]+\2?%}'
              content: '[\S\s]+'
              close: '\1{%\2?endhighlight\2?%}$'

            # ignore any liquid tags
            #
            # examples:
            #
            # - {% raw %}
            # - {% endhighlight %}
            # - {% gist somerandomeid %}
            #
            - open: '(?s)^\s{0,}?{%\s+[A-Za-z0-9]+\s+'
              close: '%}$'

            # ignore title and author in the header
            #
            # example:
            #
            # ---
            # title: My blog post title
            # author: John and Jane Doe
            # ---
            #
            - open: '(?s)^(?:title|author):'
              content: '[^\n]+'
              close: '$'

      - pyspelling.filters.markdown:
          markdown_extensions:
            - pymdownx.superfences: {}

      - pyspelling.filters.html:
          comments: false
          attributes:
            - 'title'
            - 'alt'
          ignores:
            - ':matches(code, pre)'

      - pyspelling.filters.url: {}

      - pyspelling.filters.context:
          context_visible_first: true
          escapes: '\\[\\`~]'
          delimiters:
            # ignore text between inline back ticks
            - open: '(?P<open>`+)'
              close: '(?P=open)'
{% endraw %}
```

This file is a little more difficult to read because we need to add serveral rules because of the way the spellcheck lib works (First it convert the markdown into html and then execute the spellcheck).
This code is created by the user [@sscheib](https://github.com/sscheib) and the this is the link to the [discussion](https://github.com/facelessuser/pyspelling/discussions/189#discussioncomment-8751649)

The last file doesn't need any explanation, it's for edge cases or if you want to ignore something.
