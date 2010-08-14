#include <stdio.h>
#include <stdlib.h>


/* ------------------------------------------------------
 * Estructura de datos que contiene a una matriz.
 -------------------------------------------------------- */

#define STR_ELEM "%f " /* Cadena para leer/escribir el elemento elem_t */
#define ELEMSEP "%f, " /* Cadena para escribir el resultado elem_t */

typedef float elem_t;

typedef struct matrix_t {
	unsigned rows, cols;
	unsigned start; /* Lower array bound */
	unsigned end; /* Upper array row bound */
	elem_t **data;
	elem_t **_data; /* Pointer to the mem block */
} matrix_t;



void error(char *msg)
{
	printf("Error: %s\n", msg);
	exit(1);
}


void error_not_enough_memory(void)
{
	error("No hay suficiente memoria para alojar las matrices");
}

/* Allocates memory for "rows" pointers.
 * Then memory for "cols" numbers are allocated for rows between "start" and "end"
 * Other rows aren't allocated
*/
matrix_t *matrix_alloc(unsigned rows, unsigned cols, unsigned start, unsigned end)
{
	matrix_t *result = malloc(sizeof(matrix_t));
	unsigned row;

	if (!result)
		error_not_enough_memory();

	result->rows = rows;
	result->cols = cols;
	result->start = start;
	result->end = end;

	result->_data = malloc(rows * sizeof(elem_t *));
	if (!result->_data)
		error_not_enough_memory();

	result->data = result->_data - start;
	
	for (row = start; row < end; row++) {
		result->data[row] = malloc(sizeof(elem_t) * cols);
		if (!result->data[row])
			error_not_enough_memory();
	}			

	return result;
}

/* ------------------------------------------------------
 * Lee una matriz de un fichero, pero solo un total de 
 * de FILAS / N filas, empezando en la fila (FILAS / N) * id
 * Si id es N - 1, se leen las que resten.
   ------------------------------------------------------ */
matrix_t *matrix_read_chunk(char *fname, unsigned id, unsigned N)
{
	unsigned start, end, chunk_size;
	unsigned rows, cols, row, col;
	matrix_t *r;
	elem_t dummy; /* Basura donde almacenar los elementos descartados */

	FILE *f = fopen(fname, "rt");
	if (!f) {
		printf("No se pudo abrir fichero '%s\n'", fname);
		exit(1);
	}

	fscanf(f, "%u %u\n", &rows, &cols);
	start = rows * id / N; /* Multiplicamos primero, para no perder precision */	
	chunk_size = rows / N;

	if (!chunk_size) { /* Hay demasiados procesadores. No hacemos nada si id > rows */
		if (id >= rows)
			return NULL;
		else
			chunk_size = 1; /* si id < rows, el chunk es 1 */
	}

	if (id == N - 1)
		end = rows; /* Nos aseguramos leer hasta el final si es el ultimo procesador */
	else
		end = start + chunk_size;

	/* printf("ID: %u, N: %u, Start: %u, Size: %u\n", id, N, start, chunk_size); */

	r = matrix_alloc(chunk_size, cols, start, end);

	for (row = 0; row < start; row++) /* Descartamos las filas que no nos corresponden */
		for (col = 0; col < cols; col++) {
			fscanf(f, STR_ELEM, &dummy); /* Esto es necesario en C? */
		}

	for (; row < end; row++)
		for (col = 0; col < cols; col++) {
			fscanf(f, STR_ELEM, &(r->data[row][col]));
		}

	fclose(f);

	return r;
}

/* ------------------------------------------------------
 * Read matrix from STDOUT 
 * ------------------------------------------------------ */
matrix_t *matrix_read_stdout()
{
	unsigned rows, cols, r, c;
	matrix_t *m;

	scanf("%u %u\n", &rows, &cols);

	m = matrix_alloc(rows, cols, 0, cols);

	for (r = 0; r < rows; r++) 
		for (c = 0; c < cols; c++) {
			scanf(STR_ELEM, &(m->data[r][c]));
		}

	return m;
}

/* ------------------------------------------------------
 * Lee una matriz de datos de un fichero.
 * Solo retorna si no hubo error.
 -------------------------------------------------------- */
matrix_t *matrix_read(char *fname)
{
	return matrix_read_chunk(fname, 0, 1); /* Reutilizamos la funcion anterior */
}


/* ------------------------------------------------------
 * Escribe en pantalla el contenido de una matriz, en 
 * formato "Perl"
   ------------------------------------------------------ */
void matrix_print(matrix_t *m)
{
	unsigned row, col;

	if (!m) return;

  printf("[ ");
	for (row = m->start; row < m->end; row++) {
    printf("[ ");
		for (col = 0; col < m->cols; col++)
			printf(ELEMSEP, m->data[row][col]);

		printf("],\n");
	}
  printf("]\n");
}


/* ------------------------------------------------------
 * Devuelve el producto escalar de la fila de m1 X la columna de m2
 * indicadas en fila_m1 y col_m2
   ------------------------------------------------------ */
elem_t p_escalar(matrix_t *m1, matrix_t *m2, unsigned fila_m1, unsigned col_m2)
{
	unsigned i;
	elem_t result = 0;

	for (i = 0; i < m1->cols; i++)
		result += m1->data[fila_m1][i] * m2->data[i][col_m2];

	return result;
}


/* ------------------------------------------------------
 * Devuelve el producto de m1 * m2
   ------------------------------------------------------ */
matrix_t *matrix_mult(matrix_t *m1, matrix_t *m2)
{
	matrix_t *r = NULL;
	unsigned rows, cols; /* Tamaño del resultado */
	unsigned row, col;

	if (!m1 || !m2) /* Si alguno es NULL, aborta */
		error("Alguna de las matrices es nula. Se aborta");

	if (m1->cols != m2->rows) /* (M x N) x (N x Q) => (M x Q) => comprueba las dimensiones */
		error("Las matrices no se pueden multiplicar. Error en las dimensiones.");

	rows = m1->end - m1->start;
	cols = m2->cols;

	r = matrix_alloc(rows, cols, m1->start, m1->end); /* Si se retorna, es que hubo memoria */
	
	for (row = m1->start; row < m1->end; row++)
		for (col = 0; col < cols; col++)
			r->data[row][col] = p_escalar(m1, m2, row, col);

	return r;
}



int main(int argc, char *argv[])
{
	matrix_t *m1, *m2, *m3;
	unsigned id, N;

	if (argc != 5) {
		printf("Argumentos: matrix <id> <N> <file m1> <file m2>\n");
		printf("Con:\n");
		printf("\t<id> Numero de maquina (0..N-1)\n");
		printf("\t<N> Numero total de maquinas.\n");
		printf("\t<file m1> Matrix A\n");
		printf("\t<file m2> Matrix B\n");
		exit(2);
	}

	id = atoi(argv[1]);
	N = atoi(argv[2]);

	/* printf("Numero de proceso: %u de %u\n", id, N); */
	if (id >= N)
		error("Numero de proceso fuera del rango 0..N-1");

	m1 = matrix_read_chunk(argv[3], id, N);
	m2 = matrix_read(argv[4]);
	m3 = matrix_mult(m1, m2);

	/* matrix_print(m1);
	   matrix_print(m2); */
	matrix_print(m3);

	return EXIT_SUCCESS;
}



