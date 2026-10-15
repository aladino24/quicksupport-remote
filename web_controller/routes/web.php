<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('controller', ['signalingUrl' => config('quicksupport.signaling_url')]);
});
