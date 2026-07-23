___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "AI Traffic Source",
  "description": "Detects AI referral traffic from ChatGPT, Perplexity, Gemini, Claude, Copilot, Grok and more via referrer or UTM parameters. Returns a source label or true/false for GA4 events and triggers.",
  "categories": [
    "ANALYTICS",
    "ATTRIBUTION",
    "UTILITY"
  ],
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "SELECT",
    "name": "outputType",
    "displayName": "Output type",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "source",
        "displayValue": "AI source name (e.g. chatgpt, perplexity, claude)"
      },
      {
        "value": "boolean",
        "displayValue": "Boolean (true if visit is AI-referred, false otherwise)"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "source",
    "help": "Choose \"AI source name\" to get a label you can send to GA4 as an event parameter. Choose \"Boolean\" if you only need a true/false flag for triggers."
  },
  {
    "type": "CHECKBOX",
    "name": "checkUtm",
    "checkboxText": "Also detect AI traffic from utm_source and ref query parameters",
    "simpleValueType": true,
    "defaultValue": true,
    "help": "Some AI platforms (e.g. ChatGPT) append utm_source to outbound links. Enabling this catches AI visits even when the referrer is stripped."
  },
  {
    "type": "TEXT",
    "name": "customDomains",
    "displayName": "Additional AI domains (optional)",
    "simpleValueType": true,
    "help": "Comma-separated list of domain:label pairs to extend detection, e.g. searchbot.example.com:examplebot, kagi.com:kagi. Subdomains of each listed domain are matched automatically."
  },
  {
    "type": "TEXT",
    "name": "fallbackValue",
    "displayName": "Fallback value (optional)",
    "simpleValueType": true,
    "help": "Value returned when the visit is NOT AI-referred, e.g. (none). Leave empty to return undefined.",
    "enablingConditions": [
      {
        "paramName": "outputType",
        "paramValue": "source",
        "type": "EQUALS"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const getReferrerUrl = require('getReferrerUrl');
const getUrl = require('getUrl');
const decodeUriComponent = require('decodeUriComponent');
const makeString = require('makeString');

// ---------------------------------------------------------------------------
// Known AI assistants and answer engines.
// domains: matched against the referrer hostname (subdomains included).
// utm: matched against utm_source / ref query parameter values.
// ---------------------------------------------------------------------------
const SOURCES = [
  {
    label: 'chatgpt',
    domains: ['chatgpt.com', 'chat.openai.com', 'openai.com'],
    utm: ['chatgpt', 'chatgpt.com', 'openai', 'chat.openai.com']
  },
  {
    label: 'perplexity',
    domains: ['perplexity.ai', 'pplx.ai'],
    utm: ['perplexity', 'perplexity.ai']
  },
  {
    label: 'gemini',
    domains: ['gemini.google.com', 'bard.google.com', 'aistudio.google.com'],
    utm: ['gemini', 'gemini.google.com', 'bard']
  },
  {
    label: 'claude',
    domains: ['claude.ai', 'claude.com'],
    utm: ['claude', 'claude.ai', 'anthropic']
  },
  {
    label: 'copilot',
    domains: ['copilot.microsoft.com', 'copilot.cloud.microsoft', 'edgeservices.bing.com'],
    utm: ['copilot', 'ms_copilot', 'bingchat', 'bing_chat']
  },
  {
    label: 'grok',
    domains: ['grok.com', 'x.ai'],
    utm: ['grok', 'xai']
  },
  {
    label: 'deepseek',
    domains: ['deepseek.com', 'chat.deepseek.com'],
    utm: ['deepseek']
  },
  {
    label: 'meta_ai',
    domains: ['meta.ai'],
    utm: ['meta_ai', 'meta.ai', 'metaai']
  },
  {
    label: 'mistral',
    domains: ['mistral.ai', 'chat.mistral.ai'],
    utm: ['mistral', 'lechat', 'le_chat']
  },
  {
    label: 'you',
    domains: ['you.com'],
    utm: ['you.com', 'youdotcom']
  },
  {
    label: 'poe',
    domains: ['poe.com'],
    utm: ['poe', 'poe.com']
  },
  {
    label: 'phind',
    domains: ['phind.com'],
    utm: ['phind']
  }
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// True when host equals the domain or is a subdomain of it.
const hostMatches = (host, domain) => {
  if (host === domain) return true;
  const suffix = '.' + domain;
  return host.length > suffix.length &&
    host.indexOf(suffix) === (host.length - suffix.length);
};

// Extract a query parameter value from a raw query string.
const getQueryParam = (query, name) => {
  if (!query) return '';
  const q = query.charAt(0) === '?' ? query.substring(1) : query;
  const pairs = q.split('&');
  for (let i = 0; i < pairs.length; i++) {
    const eq = pairs[i].indexOf('=');
    const key = eq === -1 ? pairs[i] : pairs[i].substring(0, eq);
    if (key === name) {
      const raw = eq === -1 ? '' : pairs[i].substring(eq + 1).split('+').join(' ');
      const decoded = decodeUriComponent(raw);
      return decoded === undefined ? raw : decoded;
    }
  }
  return '';
};

// Parse the optional custom domain list ("domain:label, domain:label").
const parseCustomDomains = (input) => {
  const out = [];
  if (!input) return out;
  const entries = makeString(input).toLowerCase().split(',');
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i].trim();
    if (!entry) continue;
    const colon = entry.indexOf(':');
    if (colon > 0) {
      out.push({
        domain: entry.substring(0, colon).trim(),
        label: entry.substring(colon + 1).trim()
      });
    } else {
      // No label supplied: use the domain itself as the label.
      out.push({ domain: entry, label: entry });
    }
  }
  return out;
};

// ---------------------------------------------------------------------------
// Detection
// ---------------------------------------------------------------------------

const referrerHost = makeString(getReferrerUrl('host') || '').toLowerCase();
const query = makeString(getUrl('query') || '').toLowerCase();
const customList = parseCustomDomains(data.customDomains);

let matchedLabel;

// 1. Referrer hostname check.
if (referrerHost) {
  for (let i = 0; i < SOURCES.length && !matchedLabel; i++) {
    for (let j = 0; j < SOURCES[i].domains.length; j++) {
      if (hostMatches(referrerHost, SOURCES[i].domains[j])) {
        matchedLabel = SOURCES[i].label;
        break;
      }
    }
  }
  for (let c = 0; c < customList.length && !matchedLabel; c++) {
    if (hostMatches(referrerHost, customList[c].domain)) {
      matchedLabel = customList[c].label;
    }
  }
}

// 2. utm_source / ref query parameter check.
if (!matchedLabel && data.checkUtm !== false && query) {
  const candidates = [
    getQueryParam(query, 'utm_source'),
    getQueryParam(query, 'ref')
  ];
  for (let k = 0; k < candidates.length && !matchedLabel; k++) {
    const value = candidates[k];
    if (!value) continue;
    for (let i = 0; i < SOURCES.length && !matchedLabel; i++) {
      if (value === SOURCES[i].label) {
        matchedLabel = SOURCES[i].label;
        break;
      }
      for (let j = 0; j < SOURCES[i].utm.length; j++) {
        if (value === SOURCES[i].utm[j]) {
          matchedLabel = SOURCES[i].label;
          break;
        }
      }
    }
    for (let c = 0; c < customList.length && !matchedLabel; c++) {
      if (value === customList[c].domain || value === customList[c].label) {
        matchedLabel = customList[c].label;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

if (data.outputType === 'boolean') {
  return matchedLabel ? true : false;
}

if (matchedLabel) {
  return matchedLabel;
}

return data.fallbackValue ? makeString(data.fallbackValue) : undefined;


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "get_referrer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_url",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Detects ChatGPT referrer
  code: |-
    mock('getReferrerUrl', (part) => part === 'host' ? 'chatgpt.com' : '');
    mock('getUrl', () => '');
    const result = runCode({outputType: 'source', checkUtm: true});
    assertThat(result).isEqualTo('chatgpt');
- name: Detects Perplexity subdomain referrer
  code: |-
    mock('getReferrerUrl', (part) => part === 'host' ? 'www.perplexity.ai' : '');
    mock('getUrl', () => '');
    const result = runCode({outputType: 'source', checkUtm: true});
    assertThat(result).isEqualTo('perplexity');
- name: Detects ChatGPT via utm_source when referrer is stripped
  code: |-
    mock('getReferrerUrl', () => '');
    mock('getUrl', (part) => part === 'query' ? 'utm_source=chatgpt.com&utm_medium=referral' : '');
    const result = runCode({outputType: 'source', checkUtm: true});
    assertThat(result).isEqualTo('chatgpt');
- name: Ignores utm detection when disabled
  code: |-
    mock('getReferrerUrl', () => '');
    mock('getUrl', (part) => part === 'query' ? 'utm_source=chatgpt.com' : '');
    const result = runCode({outputType: 'source', checkUtm: false, fallbackValue: '(none)'});
    assertThat(result).isEqualTo('(none)');
- name: Does not false-positive on lookalike domains
  code: |-
    mock('getReferrerUrl', (part) => part === 'host' ? 'notchatgpt.com.evil.io' : '');
    mock('getUrl', () => '');
    const result = runCode({outputType: 'source', checkUtm: true});
    assertThat(result).isEqualTo(undefined);
- name: Boolean output returns true for AI traffic
  code: |-
    mock('getReferrerUrl', (part) => part === 'host' ? 'claude.ai' : '');
    mock('getUrl', () => '');
    const result = runCode({outputType: 'boolean', checkUtm: true});
    assertThat(result).isEqualTo(true);
- name: Boolean output returns false for non-AI traffic
  code: |-
    mock('getReferrerUrl', (part) => part === 'host' ? 'www.google.com' : '');
    mock('getUrl', () => '');
    const result = runCode({outputType: 'boolean', checkUtm: true});
    assertThat(result).isEqualTo(false);
- name: Custom domain mapping works
  code: |-
    mock('getReferrerUrl', (part) => part === 'host' ? 'search.kagi.com' : '');
    mock('getUrl', () => '');
    const result = runCode({outputType: 'source', checkUtm: true, customDomains: 'kagi.com:kagi'});
    assertThat(result).isEqualTo('kagi');
- name: Fallback value returned for organic search traffic
  code: |-
    mock('getReferrerUrl', (part) => part === 'host' ? 'www.bing.com' : '');
    mock('getUrl', () => '');
    const result = runCode({outputType: 'source', checkUtm: true, fallbackValue: '(none)'});
    assertThat(result).isEqualTo('(none)');
setup: ''


___NOTES___

Created for the Hint GEO platform (https://hint.fyi).
Detects AI assistant and answer engine referral traffic for LLMO/GEO measurement.


