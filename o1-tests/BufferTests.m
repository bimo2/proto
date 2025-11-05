//
//  BufferTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-11-02.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "buffer.h"

#include <stddef.h>
#include <stdint.h>

@interface BufferTests : XCTestCase

@end

@implementation BufferTests

- (void)test_capacity {
    buffer_t *null = init_buffer(0);

    XCTAssertTrue(null == NULL);

    buffer_t *buffer = init_buffer(3);
    uint8_t data[] = {1, 2, 3};
    size_t overwrite;
    uint8_t read[5];
    size_t length;

    buffer_write(buffer, data, sizeof(data), NULL);
    buffer_set_capacity(buffer, 5, &overwrite);
    XCTAssertEqual(overwrite, 0);
    XCTAssertEqual(buffer_capacity(buffer), 5);
    XCTAssertEqual(buffer_size(buffer), 3);

    length = buffer_read(buffer, read, sizeof(read));
    XCTAssertEqual(length, 3);
    XCTAssertEqual(read[0], 1);
    XCTAssertEqual(read[1], 2);
    XCTAssertEqual(read[2], 3);

    uint8_t more_data[] = {4, 5};

    buffer_write(buffer, more_data, sizeof(more_data), NULL);
    buffer_set_capacity(buffer, 2, &overwrite);
    XCTAssertEqual(overwrite, 3);
    XCTAssertEqual(buffer_capacity(buffer), 2);
    XCTAssertEqual(buffer_size(buffer), 2);

    length = buffer_read(buffer, read, sizeof(read));
    XCTAssertEqual(length, 2);
    XCTAssertEqual(read[0], 4);
    XCTAssertEqual(read[1], 5);

    free_buffer(buffer);
}

- (void)test_readwrite {
    buffer_t *buffer = init_buffer(5);
    uint8_t data[] = {1, 2, 3};
    size_t overwrite;
    uint8_t read[5];
    size_t length;

    buffer_write(buffer, data, sizeof(data), &overwrite);
    XCTAssertEqual(overwrite, 0);
    XCTAssertEqual(buffer_size(buffer), 3);

    length = buffer_read(buffer, read, sizeof(read));
    XCTAssertEqual(length, 3);
    XCTAssertEqual(read[0], 1);
    XCTAssertEqual(read[1], 2);
    XCTAssertEqual(read[2], 3);
    buffer_shift(buffer, buffer_capacity(buffer));

    uint8_t more_data[] = {4, 5};

    buffer_write(buffer, more_data, sizeof(more_data), &overwrite);
    XCTAssertEqual(overwrite, 0);
    XCTAssertEqual(buffer_size(buffer), 2);

    length = buffer_read(buffer, read, sizeof(read));
    XCTAssertEqual(length, 2);
    XCTAssertEqual(read[0], 4);
    XCTAssertEqual(read[1], 5);

    uint8_t even_more_data[] = {6, 7, 8, 9, 10, 11, 12};

    buffer_write(buffer, even_more_data, sizeof(even_more_data), &overwrite);
    XCTAssertEqual(overwrite, 4);
    XCTAssertEqual(buffer_size(buffer), 5);

    length = buffer_read(buffer, read, sizeof(read));
    XCTAssertEqual(length, 5);
    XCTAssertEqual(read[0], 8);
    XCTAssertEqual(read[1], 9);
    XCTAssertEqual(read[2], 10);
    XCTAssertEqual(read[3], 11);
    XCTAssertEqual(read[4], 12);

    free_buffer(buffer);
}

- (void)test_segment {
    buffer_t *buffer = init_buffer(5);
    uint8_t data[] = {1, 2, 3, 4};
    const uint8_t *segment_a;
    const uint8_t *segment_b;
    size_t length_a;
    size_t length_b;

    buffer_write(buffer, data, sizeof(data), NULL);
    buffer_shift(buffer, 3);
    buffer_segment(buffer, &segment_a, &length_a, &segment_b, &length_b);
    XCTAssertEqual(length_a, 1);
    XCTAssertEqual(segment_a[0], 4);
    XCTAssertEqual(length_b, 0);
    XCTAssertEqual(segment_b, NULL);

    uint8_t more_data[] = {5, 6, 7, 8};

    buffer_write(buffer, more_data, sizeof(more_data), NULL);
    buffer_segment(buffer, &segment_a, &length_a, &segment_b, &length_b);
    XCTAssertEqual(length_a, 2);
    XCTAssertEqual(segment_a[0], 4);
    XCTAssertEqual(segment_a[1], 5);
    XCTAssertEqual(length_b, 3);
    XCTAssertEqual(segment_b[0], 6);
    XCTAssertEqual(segment_b[1], 7);
    XCTAssertEqual(segment_b[2], 8);

    free_buffer(buffer);
}

@end
