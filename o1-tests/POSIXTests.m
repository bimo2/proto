//
//  POSIXTests.m
//  o1-tests
//
//  Created by grok-4.1 on 2026-01-27.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "testing.h"

@interface POSIXTests : XCTestCase {
    test_t *test;
}

@end

@implementation POSIXTests

- (void)setUp {
    [super setUp];
    test_config();
    test = init_test();
    XCTAssertNotEqual(test, NULL);
}

- (void)tearDown {
    free_test(test);
    test = NULL;
    [super tearDown];
}

- (void)test_ls {
    uint8_t *data = NULL;
    size_t length = 0;
    size_t index = 0x01B6u;
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"ls" ofType:@"bin"];

    test_fixture(path.UTF8String, 0, SIZE_MAX, &data, &length);
    test_write(test, data, index);

    const char *expected_1 = "\\\\"
    "ps1: ls -a                                                               \\"
    ".                       Library                 home                     \\"
    "..                      System                  opt                      \\"
    ".VolumeIcon.icns        Users                   private                  \\"
    ".file                   Volumes                 sbin                     \\"
    ".nofollow               bin                     tmp                      \\"
    ".resolve                cores                   usr                      \\"
    ".vol                    dev                     var                      \\"
    "Applications            etc                                              \\"
    "ps1:                                                                     \\";

    test_snapshot_t snapshot_1;

    test_snapshot(snapshot_1, expected_1);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_1[i][j]);
        }
    }

    test_cursor_t cursor_1 = test_cursor(test);

    XCTAssertEqual(cursor_1.row, 11);
    XCTAssertEqual(cursor_1.column, 5);

    test_write(test, data + index, length - index);

    const char *expected_2 =
    "Applications            etc                                              \\"
    "ps1: ls -ln                                                              \\"
    "total 15                                                                 \\"
    "drwxrwxr-x  18 0  80   576 Jan 29 11:06 Applications                     \\"
    "drwxr-xr-x  66 0  0   2112 Dec 15 10:13 Library                          \\"
    "drwxr-xr-x@ 10 0  0    320 Nov 22 08:49 System                           \\"
    "drwxr-xr-x   5 0  80   160 Dec 15 10:13 Users                            \\"
    "drwxr-xr-x   3 0  0     96 Jan 20 17:39 Volumes                          \\"
    "drwxr-xr-x@ 39 0  0   1248 Nov 22 08:49 bin                              \\"
    "drwxr-xr-x   2 0  0     64 Oct 18  2024 cores                            \\"
    "dr-xr-xr-x   4 0  0   7412 Dec 15 10:12 dev                              \\"
    "lrwxr-xr-x@  1 0  0     11 Nov 22 08:49 etc -> private/etc               \\"
    "lrwxr-xr-x   1 0  0     25 Dec 15 10:13 home -> /System/Volumes/Data/home\\"
    "drwxr-xr-x   4 0  0    128 Dec  9  2024 opt                              \\"
    "drwxr-xr-x   6 0  0    192 Dec 15 10:13 private                          \\"
    "drwxr-xr-x@ 76 0  0   2432 Nov 22 08:49 sbin                             \\"
    "lrwxr-xr-x@  1 0  0     11 Nov 22 08:49 tmp -> private/tmp               \\"
    "drwxr-xr-x@ 11 0  0    352 Nov 22 08:49 usr                              \\"
    "lrwxr-xr-x@  1 0  0     11 Nov 22 08:49 var -> private/var               \\"
    "ps1:                                                                     \\";

    test_snapshot_t snapshot_2;

    test_snapshot(snapshot_2, expected_2);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_2[i][j]);
        }
    }

    test_cursor_t cursor_2 = test_cursor(test);

    XCTAssertEqual(cursor_2.row, 19);
    XCTAssertEqual(cursor_2.column, 5);

    free(data);
}

- (void)test_nano {
    uint8_t *data = NULL;
    size_t length = 0;
    size_t index_1 = 0x043Du;
    size_t index_2 = 0x05F2u;
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"nano" ofType:@"bin"];

    test_fixture(path.UTF8String, 0, SIZE_MAX, &data, &length);
    test_write(test, data, index_1);

    const char *expected_1 = "\\\\"
    "  UW PICO 5.09                       New Buffer                          \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "^G Get Help ^O WriteOut ^R Read File^Y Prev Pg  ^K Cut Text ^C Cur Pos   \\"
    "^X Exit     ^J Justify  ^W Where is ^V Next Pg  ^U UnCut Tex^T To Spell  \\";

    test_snapshot_t snapshot_1;

    test_snapshot(snapshot_1, expected_1);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_1[i][j]);
        }
    }

    test_cursor_t cursor_1 = test_cursor(test);

    XCTAssertEqual(cursor_1.row, 4);
    XCTAssertEqual(cursor_1.column, 0);

    test_write(test, data + index_1, index_2 - index_1);

    const char *expected_2 = "\\\\"
    "  UW PICO 5.09                   New Buffer                    Modified  \\"
    "                                                                         \\"
    "grok-4.1                                                                 \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "Save modified buffer (ANSWERING \"No\" WILL DESTROY CHANGES) ?           \\"
    "            Y Yes                                                        \\"
    "^C Cancel   N No                                                         \\";

    test_snapshot_t snapshot_2;

    test_snapshot(snapshot_2, expected_2);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_2[i][j]);
        }
    }

    test_cursor_t cursor_2 = test_cursor(test);

    XCTAssertEqual(cursor_2.row, 17);
    XCTAssertEqual(cursor_2.column, 61);

    test_write(test, data + index_2, length - index_2);

    const char *expected_3 = "\\\\"
    "ps1: nano                                                                \\"
    "ps1:                                                                     \\";

    test_snapshot_t snapshot_3;

    test_snapshot(snapshot_3, expected_3);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_3[i][j]);
        }
    }

    test_cursor_t cursor_3 = test_cursor(test);

    XCTAssertEqual(cursor_3.row, 3);
    XCTAssertEqual(cursor_3.column, 5);

    free(data);
}

- (void)test_tmux {
    uint8_t *data = NULL;
    size_t length = 0;
    size_t index_1 = 0x0394u;
    size_t index_2 = 0x09A9u;
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"tmux" ofType:@"bin"];

    test_fixture(path.UTF8String, 0, SIZE_MAX, &data, &length);
    test_write(test, data, index_1);

    const char *expected_1 = "\\\\"
    "ps1:                                                                     \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "                                                                         \\"
    "[119] 0:zsh*                                        \"mbp\" 21:04 29-Jan-26";

    test_snapshot_t snapshot_1;

    test_snapshot(snapshot_1, expected_1);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_1[i][j]);
        }
    }

    test_cursor_t cursor_1 = test_cursor(test);

    XCTAssertEqual(cursor_1.row, 2);
    XCTAssertEqual(cursor_1.column, 5);

    test_write(test, data + index_1, index_2 - index_1);

    const char *expected_2 = "\\\\"
    "ps1:                                │ps1:                                \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    ├────────────────────────────────────\\"
    "                                    │ps1: echo grok-4.1                  \\"
    "                                    │grok-4.1                            \\"
    "                                    │ps1:                                \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "                                    │                                    \\"
    "[119] 0:zsh*                                        \"mbp\" 21:04 29-Jan-26";

    test_snapshot_t snapshot_2;

    test_snapshot(snapshot_2, expected_2);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_2[i][j]);
        }
    }

    test_cursor_t cursor_2 = test_cursor(test);

    XCTAssertEqual(cursor_2.row, 13);
    XCTAssertEqual(cursor_2.column, 42);

    test_write(test, data + index_2, length - index_2);

    const char *expected_3 = "\\\\"
    "ps1: tmux                                                                \\"
    "[exited]                                                                 \\"
    "ps1:                                                                     \\";

    test_snapshot_t snapshot_3;

    test_snapshot(snapshot_3, expected_3);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_3[i][j]);
        }
    }

    test_cursor_t cursor_3 = test_cursor(test);

    XCTAssertEqual(cursor_3.row, 4);
    XCTAssertEqual(cursor_3.column, 5);

    free(data);
}

- (void)test_less {
    uint8_t *data = NULL;
    size_t length = 0;
    size_t index_1 = 0x041Au;
    size_t index_2 = 0x10B1u;
    size_t index_3 = 0x1A5Du;
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"less" ofType:@"bin"];

    test_fixture(path.UTF8String, 0, SIZE_MAX, &data, &length);
    test_write(test, data, index_1);

    const char *expected_1 = "\\\\"
    "NOVEMBER 17, 2025                                                        \\"
    "                                                                         \\"
    "Grok 4.1                                                                 \\"
    "                                                                         \\"
    "Grok 4.1 is now available to all users on grok.com, X, and the iOS and An\\"
    "droid apps. It is rolling out immediately in Auto mode and can be selecte\\"
    "d explicitly as \"Grok 4.1\" in the model picker.                        \\"
    "                                                                         \\"
    "We are excited to introduce Grok 4.1, which brings significant improvemen\\"
    "ts to the real-world usability of Grok. Our 4.1 model is exceptionally ca\\"
    "pable in creative, emotional, and collaborative interactions. It is more \\"
    "perceptive to nuanced intent, compelling to speak with, and coherent in p\\"
    "ersonality, while fully retaining the razor-sharp intelligence and reliab\\"
    "ility of its predecessors. To achieve this, we used the same large scale \\"
    "reinforcement learning infrastructure that powered Grok 4 and applied it \\"
    "to optimize the style, personality, helpfulness, and alignment of the mod\\"
    "el. In order to optimize these non-verifiable reward signals, we develope\\"
    "grok-4.1                                                                 \\";

    test_snapshot_t snapshot_1;

    test_snapshot(snapshot_1, expected_1);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_1[i][j]);
        }
    }

    test_cursor_t cursor_1 = test_cursor(test);

    XCTAssertEqual(cursor_1.row, 19);
    XCTAssertEqual(cursor_1.column, 8);

    test_write(test, data + index_1, index_2 - index_1);

    const char *expected_2 = "\\\\"
    "Reduced Hallucinations                                                   \\"
    "                                                                         \\"
    "Fast (non-reasoning) models equipped with search tools deliver quick answ\\"
    "ers, but they can be vulnerable to factual errors due to constrained reas\\"
    "oning depth and limited tool-call budgets.                               \\"
    "                                                                         \\"
    "In Grok 4.1 post-training, we focus on reducing factual hallucinations fo\\"
    "r information-seeking prompts. Subsequently we have observed significant \\"
    "reductions in hallucination rate for sampled production info-seeking prom\\"
    "pts.                                                                     \\"
    "                                                                         \\"
    "We evaluate hallucination rate on a stratified sample of real-world infor\\"
    "mation-seeking queries from production traffic. We also evaluate FActScor\\"
    "e, which is a public benchmark consisting of 500 biography questions on i\\"
    "ndividuals.                                                              \\"
    "                                                                         \\"
    "You can read the Grok 4.1 model card here.                               \\"
    "(END)                                                                    \\";

    test_snapshot_t snapshot_2;

    test_snapshot(snapshot_2, expected_2);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_2[i][j]);
        }
    }

    test_cursor_t cursor_2 = test_cursor(test);

    XCTAssertEqual(cursor_2.row, 19);
    XCTAssertEqual(cursor_2.column, 5);

    test_write(test, data + index_2, index_3 - index_2);

    const char *expected_3 = "\\\\"
    "Emotional Intelligence                                                   \\"
    "                                                                         \\"
    "To measure progress on our model's personality and interpersonal ability,\\"
    " we evaluated Grok 4.1 on EQ-Bench3. EQ-Bench is a LLM-judged test, evalu\\"
    "ating active emotional intelligence abilities, understanding, insight, em\\"
    "pathy, and interpersonal skills. The test set contains 45 challenging rol\\"
    "eplay scenarios, most of which constitute pre-written prompts spanning 3 \\"
    "turns. The benchmark evaluates the performance of the models by validatin\\"
    "g the models' responses against several criteria. Additionally, the bench\\"
    "mark conducts pairwise comparisons to report a normalized Elo computation\\"
    " for each model in the leaderboard.                                      \\"
    "                                                                         \\"
    "We report the rubric score and normalized Elo score by running the offici\\"
    "al benchmark repository. The scores were computed with the default sampli\\"
    "ng parameters, prescribed judge (Claude Sonnet 3.7), and no system prompt\\"
    " in accordance with the benchmark.                                       \\"
    "                                                                         \\"
    ":                                                                        \\";

    test_snapshot_t snapshot_3;

    test_snapshot(snapshot_3, expected_3);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_3[i][j]);
        }
    }

    test_cursor_t cursor_3 = test_cursor(test);

    XCTAssertEqual(cursor_3.row, 19);
    XCTAssertEqual(cursor_3.column, 1);

    test_write(test, data + index_3, length - index_3);

    const char *expected_4 = "\\\\"
    "ps1: less grok-4.1                                                       \\"
    "ps1:                                                                     \\";

    test_snapshot_t snapshot_4;

    test_snapshot(snapshot_4, expected_4);

    for (int32_t i = 0; i < TEST_ROWS; i++) {
        for (int32_t j = 0; j < TEST_COLUMNS; j++) {
            test_cell_t cell = test_cell(test, i, j);

            XCTAssertEqual(cell.codepoint, snapshot_4[i][j]);
        }
    }

    test_cursor_t cursor_4 = test_cursor(test);

    XCTAssertEqual(cursor_4.row, 3);
    XCTAssertEqual(cursor_4.column, 5);

    free(data);
}

@end
