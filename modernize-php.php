#!/usr/bin/env php
<?php
/**
 * Script to modernize PHP code to PHP 8.4 standards using PHP-Parser
 */

require_once __DIR__ . '/repos/supplier/vendor/autoload.php';

use PhpParser\Node;
use PhpParser\NodeTraverser;
use PhpParser\NodeVisitorAbstract;
use PhpParser\ParserFactory;
use PhpParser\PrettyPrinter\Standard;

if ($argc < 2) {
    echo "Usage: php modernize-php.php <directory>\n";
    exit(1);
}

$directory = $argv[1];
$parser = (new ParserFactory)->createForNewestSupportedVersion();
$traverser = new NodeTraverser();
$traverser->addVisitor(new ModernizeVisitor());
$prettyPrinter = new Standard();

$files = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($directory, RecursiveDirectoryIterator::SKIP_DOTS),
    RecursiveIteratorIterator::LEAVES_ONLY
);

foreach ($files as $file) {
    if ($file->getExtension() !== 'php') {
        continue;
    }
    
    $filepath = $file->getPathname();
    $content = file_get_contents($filepath);
    
    try {
        $ast = $parser->parse($content);
        if ($ast === null) {
            continue;
        }
        
        $modified = false;
        $newAst = $traverser->traverse($ast);
        
        // Check if modified
        $newContent = $prettyPrinter->prettyPrintFile($newAst);
        
        if ($newContent !== $content) {
            file_put_contents($filepath, $newContent);
            echo "Updated: $filepath\n";
        }
    } catch (Exception $e) {
        echo "Error parsing $filepath: " . $e->getMessage() . "\n";
    }
}

echo "Done!\n";

class ModernizeVisitor extends NodeVisitorAbstract
{
    public function leaveNode(Node $node)
    {
        // Convert $container->set(X, function() { return Y; }) to $container->set(X, fn() => Y)
        if ($node instanceof Node\Expr\MethodCall &&
            $node->var instanceof Node\Expr\Variable &&
            $node->var->name === 'container' &&
            $node->name instanceof Node\Identifier &&
            $node->name->name === 'set' &&
            count($node->args) >= 2 &&
            $node->args[1]->value instanceof Node\Expr\Closure) {
            
            $closure = $node->args[1]->value;
            
            // Check if it's a simple return
            if (count($closure->stmts) === 1 &&
                $closure->stmts[0] instanceof Node\Stmt\Return_) {
                
                $returnExpr = $closure->stmts[0]->expr;
                $arrowFunction = new Node\Expr\ArrowFunction([
                    'static' => false,
                    'byRef' => false,
                    'params' => [],
                    'returnType' => null,
                    'expr' => $returnExpr,
                ]);
                
                $node->args[1] = new Node\Arg($arrowFunction);
                return $node;
            }
        }
        
        return null;
    }
}
