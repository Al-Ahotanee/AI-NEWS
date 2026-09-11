<?php
declare(strict_types=1);
require __DIR__.'/../app/config/bootstrap.php';
if(PHP_SAPI!=='cli')exit("CLI only\n");
$pdo=db();$pdo->exec("CREATE TABLE IF NOT EXISTS schema_migrations(version VARCHAR(120) PRIMARY KEY,applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW())");$done=$pdo->query('SELECT version FROM schema_migrations')->fetchAll(PDO::FETCH_COLUMN);$files=glob(__DIR__.'/migrations/*.sql');sort($files);foreach($files as $file){$version=basename($file);if(in_array($version,$done,true))continue;$pdo->beginTransaction();try{$pdo->exec(file_get_contents($file));$s=$pdo->prepare('INSERT INTO schema_migrations(version) VALUES(?)');$s->execute([$version]);$pdo->commit();echo "Applied {$version}\n";}catch(Throwable $e){$pdo->rollBack();fwrite(STDERR,"Migration {$version} failed: {$e->getMessage()}\n");exit(1);}}
echo "Migrations are current.\n";
