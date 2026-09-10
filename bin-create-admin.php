<?php
require __DIR__.'/app/config/bootstrap.php';
if(PHP_SAPI!=='cli')exit("CLI only\n");
$name=$argv[1]??trim((string)readline('Name: '));$email=$argv[2]??trim((string)readline('Email: '));$password=getenv('ADMIN_PASSWORD')?:'';
if($password===''){system('stty -echo');$password=(string)readline('Password: ');system('stty echo');echo "\n";}
if($name===''||!filter_var($email,FILTER_VALIDATE_EMAIL)||strlen($password)<12)exit("Name, valid email, and password of at least 12 characters are required.\n");
$s=db()->prepare('INSERT INTO users(name,email,password_hash,role) VALUES(?,?,?,?) ON CONFLICT(email) DO UPDATE SET name=EXCLUDED.name,password_hash=EXCLUDED.password_hash,role=EXCLUDED.role');$s->execute([$name,$email,password_hash($password,PASSWORD_DEFAULT),'admin']);echo "Admin account ready.\n";
