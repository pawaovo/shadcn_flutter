# P1/P2 performance visual replay — 2026-09-04

**All 78 fresh PNGs are byte-identical to the individually reviewed Sep3 images.** This includes all **24 Chat, Filter, Code and Tool images** across the six existing profiles. The exporter completed with zero rendering errors.

The [JSON addendum](2026-09-04-performance-visual-regression-addendum.json) records original and current source identities, every relevant image hash, the exact capture command, and links to the full 78-image comparison. Each old retained PNG was also rehashed against the [accepted Sep3 index](2026-09-03-p1-p2-complementary-review.json). Existing individual reviews therefore apply to these identical outputs; **zero new image views are claimed**. The raw exporter manifest continues to label its captures unreviewed.

| Source inventory | SHA-256 |
| --- | --- |
| Sep3 reviewed input | `e2bcc12029aca5247f4acdaf6c3ea3f620d7dd4856f07c33c409772da5a55106` |
| Sep4 performance replay | `c5db3b710b4f9fd6abfb262606ffc20f312f9bccb07a3ff3d26a7c5059fd9c6d` |

The exporter verified the same 198 source files before and after capture; all current file hashes were checked again afterward. Repository HEAD was `36142500c9ad91dc307b6c8005e78add357f080b`, with uncommitted performance changes included in the recorded source inventory. The aggregate SHA identifies the rendered input. Five source files differ from the Sep3 baseline: Chat, Filter, Code, Tool and the previously accepted Search change.

Capture used Flutter 3.47.0 on macOS, DPR 1, the original six profiles and unchanged pinned review fonts. From `packages/beautiful_ai_ui`, the existing exporter ran:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
python3 tool/release_review/export_p1_p2_matrix.py \
  --flutter /Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter \
  --output build/release_review/2026-09-04-performance-regression
```

The exporter invokes `flutter test --no-pub`. The [fresh manifest](../../../packages/beautiful_ai_ui/build/release_review/2026-09-04-performance-regression/capture-manifest.json), [capture log](../../../packages/beautiful_ai_ui/build/release_review/2026-09-04-performance-regression/capture.log) and [complete hash comparison](../../../packages/beautiful_ai_ui/build/release_review/2026-09-04-performance-regression/all-capture-sha-comparison.json) are retained in the new output directory; prior artifacts and canonical goldens were not replaced.

Each hash below is shared by the original reviewed PNG and its fresh replay:

| Relevant capture | Original = current SHA-256 |
| --- | --- |
| `compact-dark-long-en-2x/code-block.png` | `2e97d6e1f58f571ae33a77e05f4f588d6aa4275e5307475cd7fc86a794879334` |
| `compact-dark-long-en-2x/tool-chips.png` | `51d41763ae420b44e589fcc1c3764378bf9515be369bdee4060ee6cf1cd8e3dd` |
| `compact-dark-long-en-2x/chat.png` | `1770f47b3818bd7f10b1045b152cbdaca3fb59cadd381d9ac79a1b4bdccc9ebf` |
| `compact-dark-long-en-2x/filter-table.png` | `c50fc2e0859c35ef5573533da2e8d301e645f44fcd479279bb36448cf946b043` |
| `compact-light-hc-ar-rtl-2x/code-block.png` | `15613f9ae41fbe375c1370759edd1053566171a90e676eeaea39d25de4949ae4` |
| `compact-light-hc-ar-rtl-2x/tool-chips.png` | `d9d42ffc3aa1e0722a9c01f0a81f1f191089c430cf30aa6480ed255adc4a34b2` |
| `compact-light-hc-ar-rtl-2x/chat.png` | `32d6fdb08e1df5d68d03f9376a1485b36459f8c7c66f5dc70dc1c2c417f47611` |
| `compact-light-hc-ar-rtl-2x/filter-table.png` | `8a204a4d51ed4fc7e646b402fbb15ce90a47caafae0aa55d649b0e2f17fe06c7` |
| `medium-light-zh-2x/code-block.png` | `e3a1997000c6827d5793cfc12cb6a390b465c4a48f1b25a59c5b6e1e973006ed` |
| `medium-light-zh-2x/tool-chips.png` | `a3301072e329793d7d509952d5dbbaf25eb82bf8c45db817a10b9b5b93bb627b` |
| `medium-light-zh-2x/chat.png` | `70a2aeadb41e6fd0366f83efdb59e5219877887711d725d49c959d90044c421d` |
| `medium-light-zh-2x/filter-table.png` | `73c41ae45bfa9bc846e99c5b7e71a957ac9b865c4ef5761085d9e7ba81ab1f51` |
| `medium-dark-hc-long-en-1x/code-block.png` | `1f9e013752222fc61ed484df7b8a312c1df564ef65dbfbc9612f9280729b2f69` |
| `medium-dark-hc-long-en-1x/tool-chips.png` | `7edc76526a893af49714228471b8f51a262cab36572c914aa946c1c80b620d15` |
| `medium-dark-hc-long-en-1x/chat.png` | `2823ff41a9639cc88b8b7838e049ebefd0afb9ecfd52df76917e2bab3362c044` |
| `medium-dark-hc-long-en-1x/filter-table.png` | `37d6cee7dceac21939a0d56a6f80494a7707a34182c6d7c8cf0048d2af9fa34a` |
| `expanded-light-ar-rtl-1x/code-block.png` | `d7b3cb35dc0293e451751c8cf2eac1ec96e540ca8487b4fd0fa9e4afc2de0459` |
| `expanded-light-ar-rtl-1x/tool-chips.png` | `c700fb833f879a9105aba14acd31b06e0b0aee91e8ba70cb2c5c61a5c1623a79` |
| `expanded-light-ar-rtl-1x/chat.png` | `f2b73851b642656121b56da16ef430b6151e8c166b156b1d0bbb14568526088d` |
| `expanded-light-ar-rtl-1x/filter-table.png` | `49ebecc47586e3f89383994690a428ec509aea2cb1951271b3912883a2b1534f` |
| `expanded-dark-zh-2x/code-block.png` | `b6e5e2a39fa0165f9a3a775c39c8a889a208c0deb0cebdff0e359a4ac8a3b29c` |
| `expanded-dark-zh-2x/tool-chips.png` | `c64936a98174361bb59c1050daf8b2ff5093cd437758e078e1e410792d7cb542` |
| `expanded-dark-zh-2x/chat.png` | `8ff574cc8a619538f2ac74b53c9b0d50915f744e8dd392aa86b0c93b6ed05b75` |
| `expanded-dark-zh-2x/filter-table.png` | `a1d6d253f22517a451841a83df027901a7769a7b84f56a06b629bd1cf6de3189` |

This accepts replay of the existing representative static fixtures. It does not measure the full native 200-row Filter or 500-message Chat workloads, prove runtime selection or focus behavior, or establish assistive-technology, physical-input or temporal-animation acceptance. Those remain separate evidence.
