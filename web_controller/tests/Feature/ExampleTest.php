<?php

namespace Tests\Feature;

// use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    /**
     * A basic test example.
     */
    public function test_the_application_returns_a_successful_response(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
        $response->assertSee('QuickSupport');
        $response->assertSee('controller.mjs');
    }

    public function test_signaling_configuration_is_embedded_without_executable_markup(): void
    {
        config(['quicksupport.signaling_url' => 'wss://example.test/</script><script>alert(1)</script>']);
        $response = $this->get('/');
        $response->assertOk();
        $response->assertDontSee('</script><script>alert(1)</script>', false);
        $response->assertSee('wss:\\/\\/example.test', false);
    }
}
