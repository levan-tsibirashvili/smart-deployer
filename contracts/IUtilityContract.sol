// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IUtilityContract {

    function initialize (bytes memory _initData) external returns (bool);

    // ინტერფეისის შექმნა
    // ინტერფეისის შემთხვევაში მასში არსებულ არცერთი ფუნქციას არ უნდა ქონდეს შესრულება 
    // ანუ უნდა იყოს ისეთი სახით როგორცაა function initialize 
}


/*
Домашнее задание:

1️⃣ Адаптировать ERC20Airdroper, под новую инфраструктуру Deploy Manager'a

2️⃣ Зарегистрироваться на github и запушить проект в новый репозиторий

*/