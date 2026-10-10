#include <stdint.h>

volatile uint32_t test_input = 100u;
volatile uint32_t test_result;

int main(void)
{
    uint32_t i;
    uint32_t sum = 0u;
    uint32_t limit = test_input;

    for (i = 1u; i <= limit; ++i) {
        sum += i;
    }

    test_result = sum;

    for (;;) {
    }
}
