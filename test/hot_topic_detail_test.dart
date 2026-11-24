import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/data/api.dart';

/// 一份按真实响应裁剪的 `/mo/q/newtopic/topicDetail` 报文：
/// 讨论条目都包在 `relate_thread.thread_list[].thread_info` 里。
const _topicDetailJson = '''
{
  "no": 0,
  "error": "success",
  "data": {
    "topic_info": {
      "topic_id": "28370178",
      "topic_name": "神24乘组迎来巴基斯坦航天员",
      "topic_desc": "11月24日，神舟二十四号载人飞行任务新闻发布会在酒泉卫星发射中心召开。",
      "discuss_num": "2711384",
      "topic_image": "https://tiebapic.baidu.com/topic.jpg",
      "idx_num": "2",
      "interaction_num_page": 161598
    },
    "relate_thread": {
      "thread_list": [
        {
          "feed_id": "11223194148",
          "source": 1,
          "user_agree": 0,
          "thread_info": {
            "id": 11223194148,
            "feed_id": 11223194148,
            "tid": 11223194148,
            "title": "明日指令长是唐胜杰还是汤洪波呢",
            "forum_id": 984,
            "forum_name": "航天",
            "create_time": 1795443816,
            "last_time": "11-24",
            "last_time_int": 1795494144,
            "abstract": "如果是唐，期待两位甘肃老乡重逢天宫。",
            "media": [],
            "media_num": {"pic": 0},
            "agree_num": 12,
            "reply_num": 10,
            "share_num": 1,
            "agree": {
              "agree_num": 12,
              "has_agree": 0,
              "agree_type": 0,
              "disagree_num": 0,
              "diff_agree_num": 12
            },
            "user_id": 6485957032,
            "author": {
              "id": 6485957032,
              "name": "冰56ffvv",
              "name_show": "贴吧用户_JQ4ZMPA",
              "portrait": "https://gss0.bdstatic.com/portrait1.jpg"
            },
            "rich_abstract": [
              {"type": 0, "text": "如果是唐，期待两位甘肃老乡重逢天宫。"}
            ],
            "first_post_id": 154174092203,
            "avatar": "https://imgsa.baidu.com/forum/pic/item/forum1.jpg",
            "user_agree": 0
          }
        },
        {
          "feed_id": "11218365759",
          "source": 1,
          "thread_info": {
            "id": 11218365759,
            "tid": 11218365759,
            "title": "给巴基斯坦航天员准备好了中英双语操作手册和清真餐",
            "forum_id": 984,
            "forum_name": "航天",
            "create_time": 1795307506,
            "abstract": "",
            "media": [
              {
                "type": "pic",
                "width": "560",
                "height": "1244",
                "small_pic": "https://tiebapic.baidu.com/small.jpg",
                "big_pic": "https://tiebapic.baidu.com/big.jpg",
                "water_pic": "https://tiebapic.baidu.com/big.jpg",
                "bsize": "560,1244",
                "is_long_pic": 0
              }
            ],
            "media_num": {"pic": 1},
            "agree_num": 291,
            "reply_num": 90,
            "share_num": 2,
            "agree": {
              "agree_num": 291,
              "has_agree": 0,
              "agree_type": 0,
              "disagree_num": 31,
              "diff_agree_num": 260
            },
            "user_id": 67695916,
            "author": {
              "id": 67695916,
              "name": "bttxg",
              "name_show": "bttxg",
              "portrait": "https://gss0.bdstatic.com/portrait2.jpg"
            },
            "rich_abstract": [
              {
                "type": 3,
                "src": "https://tiebapic.baidu.com/big.jpg",
                "bsize": "560,1244",
                "size": "104573",
                "origin_src": "https://tiebapic.baidu.com/big.jpg"
              }
            ],
            "first_post_id": 154167967883,
            "avatar": "https://imgsa.baidu.com/forum/pic/item/forum2.jpg"
          }
        }
      ]
    },
    "has_more": true,
    "next_topic": {"topic_id": "28370171", "topic_name": "曝TheShy入选LOL名人堂"}
  }
}
''';

Map<String, dynamic> _payload(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

void main() {
  group('parseHotTopicDetail（热议榜话题详情）', () {
    test('话题资料按字符串数字解析', () {
      final res = parseHotTopicDetail(
        _payload(_topicDetailJson),
        topicId: 1,
        topicName: '入参话题名',
      );
      expect(res.topicId, 28370178);
      expect(res.topicName, '神24乘组迎来巴基斯坦航天员');
      expect(res.topicDesc, startsWith('11月24日'));
      expect(res.topicImage, 'https://tiebapic.baidu.com/topic.jpg');
      expect(res.discussNum, 2711384);
      expect(res.hasMore, isTrue);
    });

    test('thread_list 解包 thread_info：标题、作者、吧名、计数都能显示', () {
      final threads = parseHotTopicDetail(_payload(_topicDetailJson)).threads;
      expect(threads, hasLength(2));

      final text = threads.first;
      expect(text.effectiveId, 11223194148);
      expect(text.displayTitle, '明日指令长是唐胜杰还是汤洪波呢');
      expect(text.abstractText, '如果是唐，期待两位甘肃老乡重逢天宫。');
      expect(text.author.displayName, '贴吧用户_JQ4ZMPA');
      expect(text.authorId, 6485957032);
      expect(text.forumId, 984);
      expect(text.forumName, '航天');
      expect(text.forumAvatar, 'https://imgsa.baidu.com/forum/pic/item/forum1.jpg');
      expect(text.replyNum, 10);
      expect(text.agree.displayCount, 12);
      expect(text.shareNum, 1);
      expect(text.createTime, 1795443816);
      expect(text.lastTimeInt, 1795494144);
      expect(text.lastTimeStr, '11-24');
      expect(text.firstPostId, 154174092203);
      expect(text.images, isEmpty);
    });

    test('图片贴从 media 生成配图（display 用小图，原图留 big_pic）', () {
      final pic = parseHotTopicDetail(_payload(_topicDetailJson)).threads[1];
      expect(pic.displayTitle, '给巴基斯坦航天员准备好了中英双语操作手册和清真餐');
      expect(pic.abstractText, isEmpty);
      expect(pic.images, hasLength(1));
      expect(pic.images.first.url, 'https://tiebapic.baidu.com/small.jpg');
      expect(pic.images.first.originUrl, 'https://tiebapic.baidu.com/big.jpg');
      expect(pic.images.first.width, 560);
      expect(pic.images.first.height, 1244);
      expect(pic.replyNum, 90);
      expect(pic.agree.displayCount, 291);
    });

    test('没有 media 时退回 rich_abstract 的图片节点', () {
      final res = parseHotTopicDetail(
        _payload('''
        {
          "data": {
            "relate_thread": {
              "thread_list": [
                {
                  "feed_id": "1",
                  "thread_info": {
                    "tid": 42,
                    "title": "只有图",
                    "abstract": "",
                    "rich_abstract": [
                      {
                        "type": 3,
                        "src": "https://tiebapic.baidu.com/only.jpg",
                        "bsize": "800,600",
                        "origin_src": "https://tiebapic.baidu.com/only-origin.jpg",
                        "size": "2048"
                      }
                    ]
                  }
                }
              ]
            }
          }
        }
        '''),
      );
      final t = res.threads.single;
      expect(t.images.single.url, 'https://tiebapic.baidu.com/only.jpg');
      expect(t.images.single.originUrl,
          'https://tiebapic.baidu.com/only-origin.jpg');
      expect(t.images.single.width, 800);
      expect(t.images.single.height, 600);
    });

    test('标题为空时用 rich_abstract 正文兜底，不再显示「（无标题）」', () {
      final res = parseHotTopicDetail(
        _payload('''
        {
          "data": {
            "relate_thread": {
              "thread_list": [
                {
                  "thread_info": {
                    "tid": 7,
                    "title": "",
                    "abstract": "",
                    "rich_abstract": [
                      {"type": 0, "text": "楼里这么应激吗"},
                      {"type": 2, "text": "image_emoticon3", "c": "吐舌"}
                    ]
                  }
                }
              ]
            }
          }
        }
        '''),
      );
      expect(res.threads.single.displayTitle, '楼里这么应激吗[吐舌]');
    });

    test('老结构（thread_list 直接平铺）仍然兼容', () {
      final res = parseHotTopicDetail(
        _payload('''
        {
          "data": {
            "relate_thread": {
              "thread_list": [
                {"tid": 99, "title": "旧结构", "forum_name": "航天", "reply_num": 3}
              ]
            }
          }
        }
        '''),
      );
      expect(res.threads.single.displayTitle, '旧结构');
      expect(res.threads.single.replyNum, 3);
    });

    test('空话题（topic_info 为数组、无 relate_thread）不抛异常', () {
      final res = parseHotTopicDetail(
        _payload('{"no":0,"error":"success","data":{"topic_info":[],"has_more":false}}'),
        topicId: 123,
        topicName: '入参话题名',
      );
      expect(res.topicId, 123);
      expect(res.topicName, '入参话题名');
      expect(res.discussNum, 0);
      expect(res.threads, isEmpty);
      expect(res.hasMore, isFalse);
    });
  });
}
